//
//  CustomAudioRoutePicker.swift
//  StreamVideo
//
//  Created by xskj on 2026/6/18.
//

import AVFoundation
import SwiftUI

// MARK: - Route Model

public enum AudioRouteOption: Hashable, Identifiable {
    case receiver
    case speaker
    case input(AVAudioSessionPortDescription)

    public var id: String {
        switch self {
        case .receiver: return "receiver"
        case .speaker:  return "speaker"
        case .input(let p): return "input:\(p.uid)"
        }
    }

    var title: String {
        switch self {
        case .receiver:     return "听筒"
        case .speaker:      return "扬声器"
        case .input(let p): return p.portName
        }
    }

    var systemImage: String {
        switch self {
        case .receiver:     return "iphone"
        case .speaker:      return "speaker.wave.2.fill"
        case .input(let p):
            switch p.portType {
            case .headphones, .headsetMic:  return "headphones"
            case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE: return "airpodspro"
            case .carAudio:                  return "car.fill"
            default:                         return "dot.radiowaves.left.and.right"
            }
        }
    }
}

// MARK: - Route Manager (singleton, observable)

@MainActor
public final class AudioRouteManager: ObservableObject {
    public static let shared = AudioRouteManager()

    @Published public private(set) var available: [AudioRouteOption] = []
    @Published public private(set) var current: AudioRouteOption = .receiver

    private var observer: NSObjectProtocol?

    private init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    public func refresh() {
        let session = AVAudioSession.sharedInstance()
        var options: [AudioRouteOption] = []

        // 外接设备（蓝牙、耳机）
        let inputs = session.availableInputs ?? []
        for input in inputs where Self.isExternalInput(input) {
            options.append(.input(input))
        }

        // 听筒 + 扬声器
        options.append(.receiver)
        options.append(.speaker)

        self.available = options
        self.current = Self.detectCurrent(session: session, options: options)
    }

    public func select(_ option: AudioRouteOption) {
        let session = AVAudioSession.sharedInstance()
        do {
            switch option {
            case .speaker:
                try session.setPreferredInput(nil)
                try session.overrideOutputAudioPort(.speaker)
            case .receiver:
                try session.overrideOutputAudioPort(.none)
                try session.setPreferredInput(nil)
            case .input(let port):
                try session.overrideOutputAudioPort(.none)
                try session.setPreferredInput(port)
            }
        } catch {
            print("AudioRouteManager select failed: \(error)")
        }
        // 让通知中心稍后回调刷新；这里也即刻刷新一次以减少 UI 闪烁
        refresh()
    }

    // MARK: - Helpers

    private static func isExternalInput(_ p: AVAudioSessionPortDescription) -> Bool {
        switch p.portType {
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE,
             .headphones, .headsetMic, .carAudio, .usbAudio, .lineIn:
            return true
        default:
            return false
        }
    }

    private static func detectCurrent(
        session: AVAudioSession,
        options: [AudioRouteOption]
    ) -> AudioRouteOption {
        guard let output = session.currentRoute.outputs.first else { return .receiver }
        switch output.portType {
        case .builtInSpeaker:  return .speaker
        case .builtInReceiver: return .receiver
        default:
            if let match = options.first(where: {
                if case let .input(p) = $0 { return p.uid == output.uid }
                return false
            }) {
                return match
            }
            return .receiver
        }
    }
}

// MARK: - Custom Picker Button (iOS 13+ compatible)

public struct CustomAudioRoutePicker: View {
    @ObservedObject private var manager = AudioRouteManager.shared
    @State private var presented = false

    private let onSelection: ((AudioRouteOption) -> Void)?

    public init(onSelection: ((AudioRouteOption) -> Void)? = nil) {
        self.onSelection = onSelection
    }

    public var body: some View {
        Button(action: {
            manager.refresh()
            presented = true
        }) {
            Image(systemName: manager.current.systemImage)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(red: 0x19/255, green: 0x23/255, blue: 0x2d/255))
                .clipShape(Circle())
        }
        .actionSheet(isPresented: $presented) {
            ActionSheet(
                title: Text("音频输出"),
                buttons: actionSheetButtons
            )
        }
    }

    private var actionSheetButtons: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = manager.available.map { option in
            let label = (option == manager.current) ? "\(option.title) ✓" : option.title
            return .default(Text(label)) {
                manager.select(option)
                onSelection?(option)
            }
        }
        buttons.append(.cancel(Text("取消")))
        return buttons
    }
}

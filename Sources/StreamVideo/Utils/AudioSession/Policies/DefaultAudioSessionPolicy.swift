//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import AVFoundation

/// A default implementation of the `AudioSessionPolicy` protocol.
public struct DefaultAudioSessionPolicy: AudioSessionPolicy {

    @Injected(\.applicationStateAdapter) private var applicationStateAdapter

    /// Initializes a new `DefaultAudioSessionPolicy` instance.
    public init() {}

    /// Returns the audio session configuration for the given call settings
    /// and own capabilities.
    ///
    /// - Parameters:
    ///   - callSettings: The current call settings.
    ///   - ownCapabilities: The set of the user's own audio capabilities.
    /// - Returns: The audio session configuration.
    public func configuration(
        for callSettings: CallSettings,
        ownCapabilities: Set<OwnCapability>
    ) -> AudioSessionConfiguration {
        var options: AVAudioSession.CategoryOptions = [
            .allowBluetoothHFP,
            .allowBluetoothA2DP
        ]
        if callSettings.speakerOn {
            options.insert(.defaultToSpeaker)
        }

        return .init(
            isActive: callSettings.audioOutputOn,
            category: .playAndRecord,
            mode: .voiceChat,
            options: options,
            overrideOutputAudioPort: callSettings.speakerOn
                ? .speaker
                : AVAudioSession.PortOverride.none
        )
    }
}



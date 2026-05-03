import Foundation
import WDMSystem

public enum StreamerFactory {
    /// `WDM_TEST_STREAM_LOG` switches to the recording impl;
    /// otherwise the native SCK + AVAssetWriter HLS streamer.
    public static func make(env: [String: String]) -> Streamer {
        if let p = env["WDM_TEST_STREAM_LOG"], !p.isEmpty {
            return RecordingStreamer(logURL: URL(fileURLWithPath: p))
        }
        return NativeStreamer()
    }
}

import Foundation
import WDMSystem

public enum EventStreamFactory {
    /// Build the display event stream the CLI should use given the environment.
    /// `WDM_TEST_EVENTS_FILE` switches to the hermetic file-backed stream; otherwise
    /// the real `CGDisplayEventStream` driven by `CGDisplayRegisterReconfigurationCallback`.
    public static func make(env: [String: String]) -> DisplayEventStream {
        if let path = env["WDM_TEST_EVENTS_FILE"], !path.isEmpty {
            return EventStreamFile(url: URL(fileURLWithPath: path), pollIntervalMs: 25)
        }
        return CGDisplayEventStream()
    }
}

import Foundation
import WDMCore
import WDMSystem

extension WDMController {
    /// Stream display reconfiguration events. Yields each event to `onEvent`
    /// and stops after `max` events (when set) or when the stream finishes.
    public static func watch(
        stream: DisplayEventStream,
        max: Int? = nil,
        onEvent: (DisplayEvent) throws -> Void
    ) async throws {
        var seen = 0
        for try await event in stream.events {
            try onEvent(event)
            seen += 1
            if let max, seen >= max { break }
        }
    }

    /// Frontend-friendly observer: builds the right `DisplayEventStream`
    /// for the controller's environment, runs a Task that pumps events to
    /// `onEvent`, returns a token whose `.cancel()` tears the stream down.
    /// Lets a SwiftUI / web frontend live-update on plug/unplug without
    /// importing `WDMSystem` directly (the protocol type stays in Kit).
    public func observeReconfigurations(
        onEvent: @escaping @Sendable (DisplayEvent) -> Void
    ) -> Task<Void, Never> {
        let stream = EventStreamFactory.make(env: env)
        return Task.detached {
            do {
                for try await event in stream.events {
                    onEvent(event)
                }
            } catch {
                // Stream ended (cancellation or hardware error) — frontends
                // treat this as a hint to reload manually if needed.
            }
        }
    }
}

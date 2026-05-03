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
}

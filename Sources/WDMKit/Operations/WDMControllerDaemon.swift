import Foundation
import WDMSystem

extension WDMController {
    public func runAutoProfileDaemon(
        stream: DisplayEventStream,
        max: Int?,
        onEvent: ((Bool) -> Void)? = nil
    ) async throws -> daemon.Outcome {
        try await daemon.watchAndRestore(
            stream: stream,
            provider: provider,
            auto: AutoProfileStore.resolve(from: profileStore),
            max: max,
            onEvent: onEvent
        )
    }

    public enum daemon {
        public struct Outcome: Equatable, Sendable {
            public let eventsHandled: Int
            public let profilesApplied: Int
        }

        /// Listen to display reconfiguration events, and when a saved auto-profile
        /// matches the current display set, restore it. Stops after `max` events
        /// (or never if nil — caller must rely on the event stream finishing).
        public static func watchAndRestore(
            stream: DisplayEventStream,
            provider: DisplayProvider,
            auto: AutoProfileStore,
            max: Int?,
            onEvent: ((Bool) -> Void)? = nil
        ) async throws -> Outcome {
            var seen = 0
            var applied = 0
            for try await _ in stream.events {
                seen += 1
                let didApply = try restoreIfMatching(provider: provider, auto: auto)
                if didApply { applied += 1 }
                onEvent?(didApply)
                if let max, seen >= max { break }
            }
            return Outcome(eventsHandled: seen, profilesApplied: applied)
        }

        private static func restoreIfMatching(
            provider: DisplayProvider, auto: AutoProfileStore
        ) throws -> Bool {
            let snap = try provider.snapshot()
            guard let target = try auto.load(matching: snap.displays) else { return false }
            try ProfileApplier.apply(target: target, using: provider, options: .noConfirm)
            return true
        }
    }
}

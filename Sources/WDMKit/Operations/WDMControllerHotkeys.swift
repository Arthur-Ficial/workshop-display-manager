import Foundation
import WDMSystem

extension WDMController {
    public enum hotkeys {
        public struct DaemonOutcome: Equatable, Sendable {
            public let registered: Int
            public let skipped: [String]
        }

        /// Register every enabled binding with the supplied `HotkeyRegistrar`,
        /// then run the registrar's event loop. `dispatch` runs for each fired
        /// chord. Returns when `maxEvents` events have fired (or never if nil).
        public static func runDaemon(
            bindings: [Keybinding],
            registrar: HotkeyRegistrar,
            maxEvents: Int?,
            dispatch: @escaping (String) -> Void
        ) throws -> DaemonOutcome {
            let enabled = bindings.filter { $0.enabled }
            var skipped: [String] = []
            for kb in enabled {
                do {
                    try registrar.register(chord: kb.chord)
                } catch HotkeyRegistrarError.chordTaken(let c) {
                    skipped.append(c)
                }
            }
            let chordToCommand = Dictionary(
                uniqueKeysWithValues: enabled.map { ($0.chord, $0.command) }
            )
            registrar.run(maxEvents: maxEvents) { chord in
                if let command = chordToCommand[chord] { dispatch(command) }
            }
            return DaemonOutcome(registered: enabled.count - skipped.count, skipped: skipped)
        }
    }
}

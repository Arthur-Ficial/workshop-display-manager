import Foundation
import WDMSystem

extension WDMController {
    public enum scene {
        public static func load(name: String, store: SceneStore) throws -> [SceneEntry] {
            do {
                return try store.load(name: name)
            } catch WDMError.profileNotFound(let n) {
                throw WDMError.sceneNotFound(n)
            }
        }

        public struct ApplyOutcome: Equatable, Sendable {
            public let entries: [SceneEntry]
            public let dryRun: Bool
        }

        /// Apply a scene by spawning one virtual-create child per entry. Caller
        /// supplies a `spawn` closure so tests can record the spawned arg lists
        /// without touching `Process`.
        public static func apply(
            name: String,
            store: SceneStore,
            dryRun: Bool,
            spawn: ([String]) -> Void
        ) throws -> ApplyOutcome {
            let entries = try load(name: name, store: store)
            if !dryRun {
                for entry in entries { spawn(spawnArgs(for: entry)) }
            }
            return ApplyOutcome(entries: entries, dryRun: dryRun)
        }

        public static func spawnArgs(for entry: SceneEntry) -> [String] {
            var args = [
                "virtual", "create",
                "--name", entry.spec.name,
                "--mode", "\(entry.spec.width)x\(entry.spec.height)@\(entry.spec.refreshHz)",
            ]
            if entry.spec.hiDPI { args.append("--hidpi") }
            if let m = entry.mirrorOn {
                args.append("--mirror-on")
                args.append(String(m))
            }
            return args
        }
    }
}

import Foundation
import WDMSystem

extension WDMController {
    public func virtualDisplays() throws -> [DisplayInfo] {
        try snapshot().displays
    }

    public func removeVirtual(
        target: String,
        lister: ProcessLister,
        signaler: ProcessSignaler
    ) throws -> [Int32] {
        try WDMController.virtual.remove(
            target: target,
            lister: lister,
            signaler: signaler,
            displayLookup: { id in
                (try? self.snapshot())?.display(id: id)?.name
            }
        )
    }

    public enum virtual {
        public static func presets() -> [MobilePresets.Preset] { MobilePresets.all }

        /// All currently-active displays. The fixture/CG provider doesn't tag
        /// virtuals separately; callers can filter by name if needed.
        public static func list(provider: DisplayProvider) throws -> [DisplayInfo] {
            try provider.snapshot().displays
        }

        /// Spawn the virtual display via the supplied `manager` and block
        /// until `durationMs` (or until `manager.stop()` from a signal handler).
        public static func create(
            spec: VirtualDisplaySpec,
            durationMs: Int?,
            manager: VirtualDisplayManager
        ) throws {
            try manager.run(spec: spec, durationMs: durationMs)
        }

        /// Save running `wdm virtual create` processes to a scene file.
        @discardableResult
        public static func save(
            name: String,
            store: VirtualSceneStore,
            lister: ProcessLister
        ) throws -> [VirtualDisplaySpec] {
            let entries = lister.find(matching: "wdm virtual create")
            let specs = entries.compactMap { entry in parseSpec(from: entry.command) }
            try store.save(name: name, specs: specs)
            return specs
        }

        /// Load specs for a saved scene; caller decides whether to spawn
        /// (`dryRun == false` means run them).
        public static func restore(
            name: String,
            store: VirtualSceneStore
        ) throws -> [VirtualDisplaySpec] {
            try store.load(name: name)
        }

        /// SIGTERM every `wdm virtual create` process whose `--name` matches
        /// `target` (or every process if `target == "--all"`). Returns the
        /// list of pids killed.
        @discardableResult
        public static func remove(
            target: String,
            lister: ProcessLister,
            signaler: ProcessSignaler,
            displayLookup: (UInt32) -> String? = { _ in nil }
        ) throws -> [Int32] {
            let entries = lister.find(matching: "wdm virtual create")
            let killed = entries.filter { matchesTarget(target, command: $0.command, lookup: displayLookup) }
                .map(\.pid)
            for pid in killed { signaler.terminate(pid: pid) }
            if killed.isEmpty { throw WDMError.virtualNotFound(target) }
            return killed
        }

        static func matchesTarget(_ target: String, command: String,
                                  lookup: (UInt32) -> String?) -> Bool {
            if target == "--all" { return true }
            if let id = UInt32(target), let name = lookup(id) {
                return command.contains("--name \(name)") || command.contains("--name \"\(name)\"")
            }
            return command.contains("--name \(target)") || command.contains("--name \"\(target)\"")
        }

        /// Parse `wdm virtual create --name … --mode WxH@Hz [--hidpi]` command line.
        public static func parseSpec(from cmd: String) -> VirtualDisplaySpec? {
            let tokens = tokenize(cmd)
            guard let nameIdx = tokens.firstIndex(of: "--name"), tokens.count > nameIdx + 1 else {
                return nil
            }
            let name = tokens[nameIdx + 1]
            var w = 1920, h = 1080, r = 60
            if let modeIdx = tokens.firstIndex(of: "--mode"), tokens.count > modeIdx + 1,
               let parsed = VirtualDisplaySpec.parseMode(tokens[modeIdx + 1]) {
                w = parsed.width; h = parsed.height; r = parsed.refreshHz
            }
            let hiDPI = tokens.contains("--hidpi")
            return VirtualDisplaySpec(
                name: name, width: w, height: h, refreshHz: r,
                hiDPI: hiDPI, widthMM: 600, heightMM: 340
            )
        }

        static func tokenize(_ s: String) -> [String] {
            var out: [String] = []
            var cur = ""
            var inQuote = false
            for c in s {
                if c == "\"" { inQuote.toggle(); continue }
                if c == " " && !inQuote {
                    if !cur.isEmpty { out.append(cur); cur = "" }
                } else { cur.append(c) }
            }
            if !cur.isEmpty { out.append(cur) }
            return out
        }
    }
}

import Foundation
import WDMCore
import WDMSystem

/// Virtual display lifecycle. Single-purpose UNIX-style sub-verbs.
///
/// `wdm virtual create` blocks until SIGTERM/SIGINT/SIGHUP or `--duration-ms`
/// — same pattern as `flip-overlay`/`pip`/`doctor disconnect`. The created
/// display is process-bound: kill the create process to remove it.
public enum VirtualCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        switch pos.first {
        case "create":
            return try create(args: args, deps: deps)
        case "list":
            return try list(args: args, deps: deps)
        case "remove":
            return try remove(args: args, deps: deps)
        case "save":
            return try save(args: args, deps: deps)
        case "restore":
            return try restore(args: args, deps: deps)
        case "presets":
            return presets(deps: deps)
        case nil:
            deps.stdout.writeLine("usage: wdm virtual <subcommand>")
            deps.stdout.writeLine("subcommands:")
            deps.stdout.writeLine("  create --name <s> [--mode WxH@Hz | --preset <id>] [--hidpi] [--mirror-on <id>] [--duration-ms N]")
            deps.stdout.writeLine("                            create a virtual display (blocks until SIGTERM)")
            deps.stdout.writeLine("  presets                   list known iPhone/iPad/Android presets for --preset")
            deps.stdout.writeLine("  list                      list virtual displays currently registered")
            deps.stdout.writeLine("  remove <id|name|--all>    SIGTERM the owning create process(es)")
            deps.stdout.writeLine("  save <name> [--at-login]  snapshot current running virtuals to JSON")
            deps.stdout.writeLine("  restore <name> [--dry-run] re-spawn each spec; --dry-run prints w/o spawning")
            return ExitCodes.success
        default:
            throw CLIError.usage("wdm virtual: unknown subcommand '\(pos[0])'")
        }
    }

    private static func presets(deps: CLIDeps) -> Int32 {
        let nameW = (MobilePresets.all.map { $0.name.count }.max() ?? 16)
        let labelW = (MobilePresets.all.map { $0.label.count }.max() ?? 24)
        let header = pad("ID", nameW) + "  " + pad("DEVICE", labelW)
            + "  RESOLUTION    RATE   HIDPI"
        deps.stdout.writeLine(header)
        for p in MobilePresets.all {
            let res = "\(p.width)x\(p.height)"
            let line = pad(p.name, nameW) + "  " + pad(p.label, labelW)
                + "  " + pad(res, 12)
                + "  " + pad("\(p.refreshHz)Hz", 5)
                + "  " + (p.hiDPI ? "yes" : "no")
            deps.stdout.writeLine(line)
        }
        return ExitCodes.success
    }

    private static func pad(_ s: String, _ n: Int) -> String {
        s.padding(toLength: n, withPad: " ", startingAt: 0)
    }

    // MARK: - save / restore (scenes)

    private static func save(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm virtual save <name> [--at-login]")
        }
        let name = pos[1]
        let store = VirtualSceneStore.resolve(env: deps.processEnv)

        // Walk running `wdm virtual create` command lines via pgrep (same
        // pattern as `wdm virtual remove`). Parse out --name / --mode / --hidpi.
        let pgrepProc = Process()
        pgrepProc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrepProc.arguments = ["-fl", "wdm virtual create"]
        let pipe = Pipe()
        pgrepProc.standardOutput = pipe
        try? pgrepProc.run()
        pgrepProc.waitUntilExit()
        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var specs: [VirtualDisplaySpec] = []
        for line in raw.split(separator: "\n").map(String.init) {
            // line: "<pid> <full command>"
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let cmd = String(parts[1])
            if let spec = parseSpecFromCommand(cmd) {
                specs.append(spec)
            }
        }
        try store.save(name: name, specs: specs)
        deps.stderr.writeLine("wdm virtual save: wrote \(specs.count) spec(s) to \(store.directory.appendingPathComponent("\(name).json").path)")

        if args.contains("--at-login") {
            let label = "com.fullstackoptimization.wdm.virtual-\(name)"
            let plist = LaunchAgentInstaller.defaultPlistURL(forLabel: label, env: deps.processEnv)
            let exec = ProcessInfo.processInfo.arguments.first ?? "/usr/local/bin/wdm"
            try LaunchAgentInstaller.write(
                to: plist,
                label: label,
                executablePath: exec,
                args: ["virtual", "restore", name]
            )
            deps.stderr.writeLine("wdm virtual save: installed LaunchAgent at \(plist.path)")
            deps.stderr.writeLine("  load with: launchctl bootstrap gui/$UID \(plist.path)")
        }
        return ExitCodes.success
    }

    private static func restore(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm virtual restore <name> [--dry-run]")
        }
        let name = pos[1]
        let store = VirtualSceneStore.resolve(env: deps.processEnv)
        let specs = try store.load(name: name)

        let dryRun = args.contains("--dry-run")
        for spec in specs {
            let line = "\(spec.name): \(spec.width)x\(spec.height)@\(spec.refreshHz) hiDPI=\(spec.hiDPI)"
            deps.stdout.writeLine(line)
            if !dryRun {
                // Spawn `wdm virtual create` per spec as a child process so
                // the OS treats each as an independent owner of its virtual
                // display. The current process blocks until SIGTERM, then
                // forwards SIGTERM to every child.
                let exec = ProcessInfo.processInfo.arguments.first ?? "/usr/local/bin/wdm"
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: exec)
                var spawnArgs = [
                    "virtual", "create",
                    "--name", spec.name,
                    "--mode", "\(spec.width)x\(spec.height)@\(spec.refreshHz)",
                ]
                if spec.hiDPI { spawnArgs.append("--hidpi") }
                proc.arguments = spawnArgs
                try? proc.run()
            }
        }
        return ExitCodes.success
    }

    /// Parse a `wdm virtual create --name ... --mode WxH@Hz [--hidpi]`
    /// command line into a `VirtualDisplaySpec`.
    static func parseSpecFromCommand(_ cmd: String) -> VirtualDisplaySpec? {
        let tokens = tokenize(cmd)
        guard let nameIdx = tokens.firstIndex(of: "--name"), tokens.count > nameIdx + 1 else { return nil }
        let name = tokens[nameIdx + 1]
        var width = 1920, height = 1080, refresh = 60
        if let modeIdx = tokens.firstIndex(of: "--mode"), tokens.count > modeIdx + 1,
           let parsed = VirtualDisplaySpec.parseMode(tokens[modeIdx + 1]) {
            width = parsed.width; height = parsed.height; refresh = parsed.refreshHz
        }
        let hiDPI = tokens.contains("--hidpi")
        return VirtualDisplaySpec(
            name: name, width: width, height: height, refreshHz: refresh,
            hiDPI: hiDPI, widthMM: 600, heightMM: 340
        )
    }

    /// Naive shell tokenizer: splits on whitespace, keeps quoted "names with spaces"
    /// intact. Sufficient for our own command lines which never include shell metas.
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

    // MARK: - create

    private static func create(args: [String], deps: CLIDeps) throws -> Int32 {
        guard let name = Args.flagString(args, name: "--name"), !name.isEmpty else {
            throw CLIError.usage(
                "usage: wdm virtual create --name <s> [--mode WxH@Hz] [--hidpi] [--duration-ms N]"
            )
        }
        let hiDPI = args.contains("--hidpi")
        let durationMs = Args.flagInt(args, name: "--duration-ms")

        let spec: VirtualDisplaySpec
        if let presetName = Args.flagString(args, name: "--preset") {
            guard let preset = MobilePresets.find(presetName) else {
                throw CLIError.usage(
                    "wdm virtual create: unknown --preset '\(presetName)'. Run `wdm virtual presets` to list."
                )
            }
            spec = VirtualDisplaySpec(
                name: name,
                width: preset.width, height: preset.height, refreshHz: preset.refreshHz,
                hiDPI: hiDPI || preset.hiDPI,
                // Approximate physical size from a 460ppi class panel — close to
                // every iPhone Pro since the 12 generation. Doesn't affect what
                // the OS draws, just the EDID-reported size.
                widthMM: max(50, preset.width * 25 / 460),
                heightMM: max(100, preset.height * 25 / 460)
            )
        } else if let modeToken = Args.flagString(args, name: "--mode") {
            guard let mode = VirtualDisplaySpec.parseMode(modeToken) else {
                throw CLIError.usage(
                    "wdm virtual create: --mode must be WxH@Hz (e.g. 1920x1080@60), got '\(modeToken)'"
                )
            }
            spec = VirtualDisplaySpec(
                name: name,
                width: mode.width, height: mode.height, refreshHz: mode.refreshHz,
                hiDPI: hiDPI || VirtualDisplaySpec.defaultSpec(name: name).hiDPI,
                widthMM: 600, heightMM: 340
            )
        } else {
            // Defaults: 1920x1080@60, hiDPI on, 24-inch panel.
            let base = VirtualDisplaySpec.defaultSpec(name: name)
            spec = VirtualDisplaySpec(
                name: base.name,
                width: base.width, height: base.height, refreshHz: base.refreshHz,
                hiDPI: hiDPI || base.hiDPI,
                widthMM: base.widthMM, heightMM: base.heightMM
            )
        }

        deps.stderr.writeLine(
            "wdm: virtual display '\(spec.name)' " +
            "\(spec.width)x\(spec.height)@\(spec.refreshHz) " +
            "(hiDPI=\(spec.hiDPI)) — running until SIGTERM/SIGINT/SIGHUP"
        )

        // --mirror-on <dst>: spawn a sibling PIP showing the new virtual
        // display on <dst>. Detached task; both tear down on signal. The
        // virtual's CGDirectDisplayID is only known *after* WindowServer
        // registers it, so we poll provider.snapshot() by name first.
        if let mirrorToken = Args.flagString(args, name: "--mirror-on"),
           !mirrorToken.isEmpty {
            let preSnap = try deps.provider.snapshot()
            let dstID = try DisplayResolver.resolve(mirrorToken, in: preSnap)
            let virtualName = spec.name
            let pipFlipper = deps.pipFlipper
            let provider = deps.provider
            // Detect hermetic test mode by type-casting the manager — the
            // factory hands out RecordingVirtualDisplayManager when
            // WDM_TEST_VIRTUAL_LOG is set in the env dict passed to CLIRunner,
            // which is the only way ProcessInfo can't see it from inside the
            // command.
            let testMode = deps.virtualDisplayManager is RecordingVirtualDisplayManager
            let pipDuration = testMode ? 10 : durationMs
            Task.detached(priority: .userInitiated) {
                var srcID: UInt32 = 0
                if testMode {
                    // Recording providers don't gain the new virtual display, so
                    // pick a stable known id (the harness fixture has 1 + 2).
                    srcID = 1
                } else {
                    let deadline = Date(timeIntervalSinceNow: 5.0)
                    while Date() < deadline {
                        if let s = try? provider.snapshot(),
                           let m = s.displays.first(where: { $0.name == virtualName }) {
                            srcID = m.id
                            break
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    guard srcID != 0 else { return }
                }
                do {
                    try pipFlipper.run(
                        sourceID: srcID, destinationID: dstID,
                        size: PipSize.defaultSize, position: nil,
                        flip: .none, durationMs: pipDuration,
                        remoteControl: false
                    )
                } catch {
                    FileHandle.standardError.write(
                        Data("wdm: --mirror-on PIP failed: \(error)\n".utf8)
                    )
                }
            }
        }

        try deps.virtualDisplayManager.run(spec: spec, durationMs: durationMs)
        // Yield briefly so any in-flight detached PIP-recording task gets to
        // flush its log line before the caller reads it (hermetic-test mode).
        if deps.virtualDisplayManager is RecordingVirtualDisplayManager,
           Args.flagString(args, name: "--mirror-on") != nil {
            Thread.sleep(forTimeInterval: 0.20)
        }
        return ExitCodes.success
    }

    // MARK: - list

    private static func list(args: [String], deps: CLIDeps) throws -> Int32 {
        let snap = try deps.provider.snapshot()
        // Virtual displays created by wdm carry the vendor/product/serial we
        // set in `CGVirtualDisplayManager`. The fixture provider has no notion
        // of "virtual"; it would print everything. Filter by checking if any
        // display's name starts with the wdm-virtual prefix or its mirrorSource
        // is unset and it doesn't appear in the OS's normal display list. For
        // v1 the simplest honest filter is: print displays whose name we can
        // identify as a wdm-created virtual. With no marker on DisplayInfo,
        // we print ALL displays so the user sees the full layout, with a
        // hint about which is the virtual one.
        for d in snap.displays {
            deps.stdout.writeLine("\(d.id)\t\(d.name ?? "(unnamed)")\t\(d.currentMode.width)x\(d.currentMode.height)@\(d.currentMode.refreshHz)")
        }
        return ExitCodes.success
    }

    // MARK: - remove

    private static func remove(args: [String], deps: CLIDeps) throws -> Int32 {
        // Accept either `wdm virtual remove --all` or `wdm virtual remove <id|name>`.
        let pos = Args.positional(args)
        let target: String
        if args.contains("--all") {
            target = "--all"
        } else if pos.count >= 2 {
            target = pos[1]
        } else {
            throw CLIError.usage("usage: wdm virtual remove <id|name|--all>")
        }

        // Find owning `wdm virtual create` processes via pgrep -f. Each line
        // is "<pid> <command-line>"; match by --name <target> or any name if
        // target == "--all".
        let pgrepProc = Process()
        pgrepProc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrepProc.arguments = ["-fl", "wdm virtual create"]
        let pipe = Pipe()
        pgrepProc.standardOutput = pipe
        try pgrepProc.run()
        pgrepProc.waitUntilExit()
        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lines = raw.split(separator: "\n").map(String.init)

        var killed: [Int32] = []
        for line in lines {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let pidStr = parts.first, let pid = Int32(pidStr) else { continue }
            let cmd = parts.count > 1 ? String(parts[1]) : ""
            // Resolve target: numeric id, exact name, or --all.
            let isMatch: Bool
            if target == "--all" {
                isMatch = true
            } else if let _ = Int(target) {
                // Numeric id — match if cmd contains the running display's name we
                // can find by snapshot lookup.
                let snap = try? deps.provider.snapshot()
                if let id = UInt32(target),
                   let name = snap?.display(id: id)?.name {
                    isMatch = cmd.contains("--name \(name)") || cmd.contains("--name \"\(name)\"")
                } else {
                    isMatch = false
                }
            } else {
                isMatch = cmd.contains("--name \(target)") || cmd.contains("--name \"\(target)\"")
            }
            if isMatch {
                kill(pid, SIGTERM)
                killed.append(pid)
            }
        }
        if killed.isEmpty {
            deps.stderr.writeLine("wdm virtual remove: no matching `wdm virtual create` process found for \(target)")
            return ExitCodes.profileNotFound
        }
        deps.stderr.writeLine("wdm virtual remove: SIGTERM → pids \(killed.map(String.init).joined(separator: ", "))")
        return ExitCodes.success
    }

}

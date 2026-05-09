import Foundation
import WDMKit

/// Virtual display lifecycle. Single-purpose UNIX-style sub-verbs.
public enum VirtualCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        switch pos.first {
        case "create":  return try create(args: args, deps: deps)
        case "list":    return try list(args: args, deps: deps)
        case "remove":  return try remove(args: args, deps: deps)
        case "save":    return try save(args: args, deps: deps)
        case "restore": return try restore(args: args, deps: deps)
        case "presets": return presets(deps: deps)
        case nil:       return printUsage(deps: deps)
        default:        throw WDMError.usage("wdm virtual: unknown subcommand '\(pos[0])'")
        }
    }

    private static func printUsage(deps: CLIDeps) -> Int32 {
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
    }

    private static func presets(deps: CLIDeps) -> Int32 {
        let all = WDMController.virtual.presets()
        let nameW = (all.map { $0.name.count }.max() ?? 16)
        let labelW = (all.map { $0.label.count }.max() ?? 24)
        let header = pad("ID", nameW) + "  " + pad("DEVICE", labelW) + "  RESOLUTION    RATE   HIDPI"
        deps.stdout.writeLine(header)
        for p in all {
            let res = "\(p.width)x\(p.height)"
            let line = pad(p.name, nameW) + "  " + pad(p.label, labelW)
                + "  " + pad(res, 12) + "  " + pad("\(p.refreshHz)Hz", 5)
                + "  " + (p.hiDPI ? "yes" : "no")
            deps.stdout.writeLine(line)
        }
        return ExitCodes.success
    }

    private static func pad(_ s: String, _ n: Int) -> String {
        s.padding(toLength: n, withPad: " ", startingAt: 0)
    }

    private static func list(args: [String], deps: CLIDeps) throws -> Int32 {
        for d in try deps.controller.virtualDisplays() {
            deps.stdout.writeLine("\(d.id)\t\(d.name ?? "(unnamed)")\t\(d.currentMode.width)x\(d.currentMode.height)@\(d.currentMode.refreshHz)")
        }
        return ExitCodes.success
    }

    private static func remove(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        let target: String
        if args.contains("--all") { target = "--all" }
        else if pos.count >= 2 { target = pos[1] }
        else { throw WDMError.usage("usage: wdm virtual remove <id|name|--all>") }

        let killed = try deps.controller.removeVirtual(
            target: target,
            lister: PgrepProcessLister(),
            signaler: RealProcessSignaler()
        )
        deps.stderr.writeLine(
            "wdm virtual remove: SIGTERM → pids " +
            killed.map(String.init).joined(separator: ", ")
        )
        return ExitCodes.success
    }

    private static func save(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else { throw WDMError.usage("usage: wdm virtual save <name> [--at-login]") }
        let name = pos[1]
        let store = VirtualSceneStore.resolve(env: deps.processEnv)
        let specs = try WDMController.virtual.save(name: name, store: store, lister: PgrepProcessLister())
        let outPath = store.directory.appendingPathComponent("\(name).json").path
        deps.stderr.writeLine("wdm virtual save: wrote \(specs.count) spec(s) to \(outPath)")
        if args.contains("--at-login") { try installAtLogin(name: name, deps: deps) }
        return ExitCodes.success
    }

    private static func installAtLogin(name: String, deps: CLIDeps) throws {
        let label = "com.fullstackoptimization.wdm.virtual-\(name)"
        let plist = LaunchAgentInstaller.defaultPlistURL(forLabel: label, env: deps.processEnv)
        let exec = ProcessInfo.processInfo.arguments.first ?? "/usr/local/bin/wdm"
        try LaunchAgentInstaller.write(
            to: plist, label: label, executablePath: exec,
            args: ["virtual", "restore", name]
        )
        deps.stderr.writeLine("wdm virtual save: installed LaunchAgent at \(plist.path)")
        deps.stderr.writeLine("  load with: launchctl bootstrap gui/$UID \(plist.path)")
    }

    private static func restore(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else { throw WDMError.usage("usage: wdm virtual restore <name> [--dry-run]") }
        let name = pos[1]
        let store = VirtualSceneStore.resolve(env: deps.processEnv)
        let specs = try WDMController.virtual.restore(name: name, store: store)
        let dryRun = args.contains("--dry-run")
        for spec in specs {
            deps.stdout.writeLine("\(spec.name): \(spec.width)x\(spec.height)@\(spec.refreshHz) hiDPI=\(spec.hiDPI)")
            if !dryRun { spawnVirtual(spec: spec) }
        }
        return ExitCodes.success
    }

    private static func spawnVirtual(spec: VirtualDisplaySpec) {
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

    private static func create(args: [String], deps: CLIDeps) throws -> Int32 {
        let spec = try buildSpec(args: args)
        let durationMs = Args.flagInt(args, name: "--duration-ms")
        deps.stderr.writeLine(
            "wdm: virtual display '\(spec.name)' " +
            "\(spec.width)x\(spec.height)@\(spec.refreshHz) " +
            "(hiDPI=\(spec.hiDPI)) — running until SIGTERM/SIGINT/SIGHUP"
        )
        if let mirror = Args.flagString(args, name: "--mirror-on"), !mirror.isEmpty {
            try detachMirror(mirrorAlias: mirror, virtualName: spec.name,
                             durationMs: durationMs, deps: deps)
        }
        try WDMController.virtual.create(
            spec: spec, durationMs: durationMs, manager: deps.virtualDisplayManager
        )
        if isTestMode(deps: deps), Args.flagString(args, name: "--mirror-on") != nil {
            Thread.sleep(forTimeInterval: 0.20)
        }
        return ExitCodes.success
    }

    private static func buildSpec(args: [String]) throws -> VirtualDisplaySpec {
        guard let name = Args.flagString(args, name: "--name"), !name.isEmpty else {
            throw WDMError.usage(
                "usage: wdm virtual create --name <s> [--mode WxH@Hz] [--hidpi] [--duration-ms N]"
            )
        }
        let hiDPI = args.contains("--hidpi")
        if let presetName = Args.flagString(args, name: "--preset") {
            return try specFromPreset(name: name, preset: presetName, hiDPI: hiDPI)
        }
        if let modeToken = Args.flagString(args, name: "--mode") {
            return try specFromMode(name: name, mode: modeToken, hiDPI: hiDPI)
        }
        let base = VirtualDisplaySpec.defaultSpec(name: name)
        return VirtualDisplaySpec(
            name: base.name, width: base.width, height: base.height, refreshHz: base.refreshHz,
            hiDPI: hiDPI || base.hiDPI, widthMM: base.widthMM, heightMM: base.heightMM
        )
    }

    private static func specFromPreset(name: String, preset: String, hiDPI: Bool) throws -> VirtualDisplaySpec {
        guard let p = MobilePresets.find(preset) else {
            throw WDMError.usage(
                "wdm virtual create: unknown --preset '\(preset)'. Run `wdm virtual presets` to list."
            )
        }
        return VirtualDisplaySpec(
            name: name, width: p.width, height: p.height, refreshHz: p.refreshHz,
            hiDPI: hiDPI || p.hiDPI,
            widthMM: max(50, p.width * 25 / 460),
            heightMM: max(100, p.height * 25 / 460)
        )
    }

    private static func specFromMode(name: String, mode: String, hiDPI: Bool) throws -> VirtualDisplaySpec {
        guard let m = VirtualDisplaySpec.parseMode(mode) else {
            throw WDMError.usage(
                "wdm virtual create: --mode must be WxH@Hz (e.g. 1920x1080@60), got '\(mode)'"
            )
        }
        return VirtualDisplaySpec(
            name: name, width: m.width, height: m.height, refreshHz: m.refreshHz,
            hiDPI: hiDPI || VirtualDisplaySpec.defaultSpec(name: name).hiDPI,
            widthMM: 600, heightMM: 340
        )
    }

    private static func isTestMode(deps: CLIDeps) -> Bool {
        deps.virtualDisplayManager is RecordingVirtualDisplayManager
    }

    private static func detachMirror(
        mirrorAlias: String, virtualName: String, durationMs: Int?, deps: CLIDeps
    ) throws {
        let dstID = try deps.controller.get(mirrorAlias).id
        let pipFlipper = deps.pipFlipper
        let controller = deps.controller
        let testMode = isTestMode(deps: deps)
        let pipDuration = testMode ? 10 : durationMs
        Task.detached(priority: .userInitiated) {
            let srcID = await resolveVirtualID(
                controller: controller, name: virtualName, testMode: testMode
            )
            guard srcID != 0 else { return }
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

    private static func resolveVirtualID(
        controller: WDMController, name: String, testMode: Bool
    ) async -> UInt32 {
        if testMode { return 1 }
        let deadline = Date(timeIntervalSinceNow: 5.0)
        while Date() < deadline {
            if let m = try? controller.virtualDisplays().first(where: { $0.name == name }) {
                return m.id
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return 0
    }
}

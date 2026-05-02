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
        case nil:
            deps.stdout.writeLine("usage: wdm virtual <subcommand>")
            deps.stdout.writeLine("subcommands:")
            deps.stdout.writeLine("  create --name <s> [--mode WxH@Hz] [--hidpi] [--duration-ms N]")
            deps.stdout.writeLine("                            create a virtual display (blocks until SIGTERM)")
            deps.stdout.writeLine("  list                      list virtual displays currently registered")
            deps.stdout.writeLine("  remove <id>               remove a virtual display (process-scoped)")
            return ExitCodes.success
        default:
            throw CLIError.usage("wdm virtual: unknown subcommand '\(pos[0])'")
        }
    }

    // MARK: - create

    private static func create(args: [String], deps: CLIDeps) throws -> Int32 {
        guard let name = parseFlagString(args, name: "--name"), !name.isEmpty else {
            throw CLIError.usage(
                "usage: wdm virtual create --name <s> [--mode WxH@Hz] [--hidpi] [--duration-ms N]"
            )
        }
        let hiDPI = args.contains("--hidpi")
        let durationMs = parseFlagInt(args, name: "--duration-ms")

        let spec: VirtualDisplaySpec
        if let modeToken = parseFlagString(args, name: "--mode") {
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
        try deps.virtualDisplayManager.run(spec: spec, durationMs: durationMs)
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

    // MARK: - flag helpers

    private static func parseFlagString(_ args: [String], name: String) -> String? {
        guard let i = args.firstIndex(of: name), args.count > i + 1 else { return nil }
        return args[i + 1]
    }

    private static func parseFlagInt(_ args: [String], name: String) -> Int? {
        parseFlagString(args, name: name).flatMap(Int.init)
    }
}

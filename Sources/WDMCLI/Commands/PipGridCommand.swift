import WDMKit

public enum PipGridCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let csvList = pos.first, !csvList.isEmpty else {
            throw WDMError.usage(
                "usage: wdm pip-grid <id1,id2,...> [--on <dst>] [--cols N] [--duration-ms N]"
            )
        }
        let plan = try buildPlan(csvList: csvList, args: args, deps: deps)
        try deps.controller.pipGrid(plan: plan, using: deps.pipFlipper)
        return ExitCodes.success
    }

    private static func buildPlan(csvList: String, args: [String], deps: CLIDeps) throws -> WDMController.PipGridPlan {
        let sources = csvList.split(separator: ",").map(String.init)
        let destination = try resolveDestination(args: args, deps: deps)
        let cols: Int?
        if let c = Args.flagString(args, name: "--cols"), let n = Int(c), n > 0 {
            cols = n
        } else { cols = nil }
        let duration = computeDuration(args: args, deps: deps)
        return WDMController.PipGridPlan(
            sourceAliases: sources, destinationAlias: destination,
            cols: cols, durationMs: duration, margin: 8
        )
    }

    private static func resolveDestination(args: [String], deps: CLIDeps) throws -> String {
        if let dst = Args.flagString(args, name: "--on"), !dst.isEmpty { return dst }
        return "main"
    }

    private static func computeDuration(args: [String], deps: CLIDeps) -> Int? {
        let testMode = deps.virtualDisplayManager is RecordingVirtualDisplayManager
            || deps.processEnv["WDM_TEST_PIP_LOG"].map({ !$0.isEmpty }) ?? false
        let userDur = Args.flagInt(args, name: "--duration-ms")
        return testMode ? 10 : userDur
    }
}

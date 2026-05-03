import WDMKit

/// PIP that re-targets its source whenever the cursor enters a different
/// display. Polls `cursorTracker` once per `--poll-ms` (default 500ms) and,
/// when the source changes, calls `pipFlipper.run(...)` again.
public enum FollowCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let dstAlias = pos.first, !dstAlias.isEmpty else {
            throw WDMError.usage("usage: wdm follow <dst|main> [--poll-ms N] [--duration-ms N]")
        }
        let plan = WDMController.FollowPlan(
            destinationAlias: dstAlias,
            pollMs: Args.flagInt(args, name: "--poll-ms") ?? 500,
            durationMs: Args.flagInt(args, name: "--duration-ms")
        )
        try deps.controller.follow(plan: plan, cursor: deps.cursorTracker, pip: deps.pipFlipper)
        return ExitCodes.success
    }
}

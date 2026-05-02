import WDMSystem

public enum SwitchCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let snap = try deps.provider.snapshot()
        guard snap.displays.count >= 2, let main = snap.main else {
            throw CLIError.usage("switch requires at least two displays with a main")
        }
        let other = snap.displays.first { $0.id != main.id && $0.isOnline }
        guard let target = other else {
            throw CLIError.usage("no second display available to switch to")
        }
        let label = target.name ?? "display \(target.id)"
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Switched main to \(label)"
        ) {
            try deps.provider.setMain(displayID: target.id, options: .noConfirm)
        }
    }
}

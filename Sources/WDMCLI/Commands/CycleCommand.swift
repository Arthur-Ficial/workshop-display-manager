import WDMSystem

public enum CycleCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let snap = try deps.provider.snapshot()
        let online = snap.displays.filter { $0.isOnline }
        guard online.count >= 2, let mainIdx = online.firstIndex(where: { $0.isMain }) else {
            throw CLIError.usage("cycle requires at least two online displays with a main")
        }
        let next = online[(mainIdx + 1) % online.count]
        let label = next.name ?? "display \(next.id)"
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Cycled main to \(label)"
        ) {
            try deps.provider.setMain(displayID: next.id, options: .noConfirm)
        }
    }
}

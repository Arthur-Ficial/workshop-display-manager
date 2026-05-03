public enum CycleCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let result = try deps.controller.cycleMain(
            confirmer: MutationDispatch.pickConfirmer(deps: deps, args: args)
        )
        return MutationDispatch.mapResult(result, deps: deps)
    }
}

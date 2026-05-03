import WDMSystem

public enum MirrorCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm mirror <src> <dst> [<dst2> ...] [--no-confirm]")
        }
        let snap = try deps.provider.snapshot()
        let src = try DisplayResolver.resolve(pos[0], in: snap)
        let targets = try pos.dropFirst().map { try DisplayResolver.resolve($0, in: snap) }
        let srcLabel = snap.display(id: src)?.name ?? "display \(src)"
        let targetsLabel = targets
            .map { snap.display(id: $0)?.name ?? "display \($0)" }
            .joined(separator: ", ")
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Mirroring \(targetsLabel) → \(srcLabel)"
        ) {
            try deps.provider.mirror(source: src, targets: targets, options: .noConfirm)
        }
    }
}

public enum UnmirrorCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm unmirror <id> [--no-confirm]")
        }
        let snap = try deps.provider.snapshot()
        let id = try DisplayResolver.resolve(alias, in: snap)
        let label = snap.display(id: id)?.name ?? "display \(id)"
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Stopped mirroring \(label)"
        ) {
            try deps.provider.unmirror(displayID: id, options: .noConfirm)
        }
    }
}

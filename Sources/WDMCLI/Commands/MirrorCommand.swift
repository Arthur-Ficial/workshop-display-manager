import WDMSystem

public enum MirrorCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 2 else {
            throw CLIError.usage("usage: wdm mirror <src> <dst> [--no-confirm]")
        }
        let snap = try deps.provider.snapshot()
        let src = try DisplayResolver.resolve(pos[0], in: snap)
        let dst = try DisplayResolver.resolve(pos[1], in: snap)
        let srcLabel = snap.display(id: src)?.name ?? "display \(src)"
        let dstLabel = snap.display(id: dst)?.name ?? "display \(dst)"
        return try MutationDispatch.dispatch(
            deps: deps, args: args,
            description: "Mirroring \(dstLabel) → \(srcLabel)"
        ) {
            try deps.provider.mirror(source: src, mirror: dst, options: .noConfirm)
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

import Foundation

/// `wdm wallpaper <id|main> [--json]` — print the file URL of the
/// desktop wallpaper currently set on the given display.
///
/// `wdm wallpaper set <id|main> <path> [--no-confirm|--confirm]` —
/// set the wallpaper of `<id>` to the file at `<path>`. Routes through
/// the SafeMutation 15s revert path so an unwanted wallpaper can be
/// rolled back like any other display change.
///
/// Empty stdout (exit 0) on the read path when no wallpaper is set —
/// honest refusal per CLAUDE.md.
public enum WallpaperCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        if pos.first == "set" { return try runSet(args: args, deps: deps) }
        return try runGet(args: args, deps: deps)
    }

    private static func runGet(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage(
                "usage: wdm wallpaper <id|main> [--json]\n" +
                "       wdm wallpaper set <id|main> <path> [--no-confirm|--confirm]"
            )
        }
        let url = try deps.controller.wallpaper(alias)
        let wantsJSON = args.contains("--json")
        if wantsJSON {
            let payload: [String: Any] = ["wallpaper": url?.path as Any]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            deps.stdout.writeLine(String(data: data, encoding: .utf8) ?? "{}")
        } else if let path = url?.path, !path.isEmpty {
            deps.stdout.writeLine(path)
        }
        return ExitCodes.success
    }

    private static func runSet(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard pos.count >= 3 else {
            throw CLIError.usage("usage: wdm wallpaper set <id|main> <path> [--no-confirm|--confirm]")
        }
        let alias = pos[1]
        let path = pos[2]
        let url = URL(fileURLWithPath: path)
        let confirmer = MutationDispatch.pickConfirmer(deps: deps, args: args)
        let result = try deps.controller.setWallpaper(alias, url: url, confirmer: confirmer)
        return MutationDispatch.mapResult(result, deps: deps)
    }
}

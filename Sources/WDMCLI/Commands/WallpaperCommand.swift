import Foundation

/// `wdm wallpaper <id|main> [--json]` — print the file URL of the
/// desktop wallpaper currently set on the given display. Empty output
/// (exit 0) when the display has no wallpaper set, matching the unix
/// idiom for "no result." Honest refusal per CLAUDE.md — does NOT
/// invent a placeholder.
public enum WallpaperCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let pos = Args.positional(args)
        guard let alias = pos.first else {
            throw CLIError.usage("usage: wdm wallpaper <id|main> [--json]")
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
}

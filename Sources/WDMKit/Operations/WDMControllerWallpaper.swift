import Foundation
import WDMSystem

extension WDMController {
    /// Read the desktop wallpaper URL currently set on the given display.
    /// Mirrors `wdm wallpaper <id>`. Returns nil for unknown displays
    /// or displays without a wallpaper set — honest refusal per
    /// CLAUDE.md (no fake "default" image).
    public func wallpaper(_ alias: String) throws -> URL? {
        let id = try resolve(alias)
        return WallpaperProviderFactory.make(env: env).wallpaper(for: id)
    }

    /// Set the desktop wallpaper of the given display to `url`. Mirrors
    /// `wdm wallpaper set <id> <path>`. Snapshots the previous URL,
    /// applies the new one, asks the confirmer, and on
    /// timeout/revert restores the previous wallpaper (or leaves the
    /// new one if there was no previous URL — Workspace's own
    /// "no wallpaper" state isn't restorable through the public API).
    public func setWallpaper(_ alias: String, url: URL, confirmer: Confirmer) throws -> ApplyResult {
        let id = try resolve(alias)
        let provider = WallpaperProviderFactory.make(env: env)
        let previous = provider.wallpaper(for: id)
        try provider.setWallpaper(for: id, url: url)
        if confirmer.confirm(message: "Change wallpaper", timeoutSeconds: 15) {
            return .applied
        }
        if let prev = previous {
            try? provider.setWallpaper(for: id, url: prev)
        }
        return .reverted
    }
}

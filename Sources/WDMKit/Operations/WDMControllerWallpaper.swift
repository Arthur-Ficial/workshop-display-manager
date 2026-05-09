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
}

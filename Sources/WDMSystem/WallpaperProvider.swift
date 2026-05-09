import Foundation
import AppKit

/// Read-side abstraction for the desktop wallpaper currently set on a
/// display. Powers tile previews (every monitor's tile in WDMMac shows a
/// miniature of its real desktop) and `wdm wallpaper <id>` JSON output.
///
/// The protocol is sync because `NSWorkspace.desktopImageURL(for:)` is
/// already synchronous and very fast (in-memory lookup against the
/// workspace's plist cache). Higher-level caching is a separate concern
/// (e.g. the WDMMac VM reloads on `NSWorkspace.didChangeDesktopImage`).
public protocol WallpaperProvider: Sendable {
    /// File URL of the wallpaper currently set on `displayID`. Returns
    /// nil for an unknown display, a display with no wallpaper set, or
    /// a transient lookup failure (the workspace may be mid-update).
    func wallpaper(for displayID: UInt32) -> URL?
}

/// Hermetic test provider — feeds `[displayID: URL]` from an in-memory
/// dictionary or a fixture JSON file `{ "1": "/path/to/wp.jpg", "2": ... }`.
/// Activated by `WDM_TEST_WALLPAPER` env var pointing at the fixture.
public struct RecordingWallpaperProvider: WallpaperProvider {
    private let mappings: [UInt32: URL]

    public init(mappings: [UInt32: URL]) {
        self.mappings = mappings
    }

    public init(fixtureURL: URL) throws {
        let data = try Data(contentsOf: fixtureURL)
        let dict = (try JSONSerialization.jsonObject(with: data) as? [String: String]) ?? [:]
        var m: [UInt32: URL] = [:]
        for (k, v) in dict {
            if let id = UInt32(k) { m[id] = URL(fileURLWithPath: v) }
        }
        self.mappings = m
    }

    public func wallpaper(for displayID: UInt32) -> URL? {
        mappings[displayID]
    }
}

/// Real macOS provider — looks up the `NSScreen` whose
/// `NSScreenNumber` matches `displayID`, asks `NSWorkspace` for its
/// current wallpaper. Pure public API; no entitlement or TCC dance.
public struct NSWorkspaceWallpaperProvider: WallpaperProvider {
    public init() {}

    public func wallpaper(for displayID: UInt32) -> URL? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[key] as? UInt32,
                  number == displayID else { continue }
            return NSWorkspace.shared.desktopImageURL(for: screen)
        }
        return nil
    }
}

/// Picks the recording provider when `WDM_TEST_WALLPAPER` points at a
/// readable JSON fixture, the real provider otherwise. Mirrors the
/// `DisplayProviderFactory` / `OverlayFlipper` factory pattern.
public enum WallpaperProviderFactory {
    public static func make(env: [String: String]) -> WallpaperProvider {
        if let path = env["WDM_TEST_WALLPAPER"], !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            if let prov = try? RecordingWallpaperProvider(fixtureURL: url) {
                return prov
            }
            return RecordingWallpaperProvider(mappings: [:])
        }
        return NSWorkspaceWallpaperProvider()
    }
}

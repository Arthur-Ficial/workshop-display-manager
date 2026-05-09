import Foundation
import AppKit

/// Read-side abstraction for the desktop wallpaper currently set on a
/// display. Powers `wdm wallpaper <id>` JSON output.
///
/// The protocol is sync because `NSWorkspace.desktopImageURL(for:)` is
/// already synchronous and very fast (in-memory lookup against the
/// workspace's plist cache). Higher-level caching is a separate concern.
public protocol WallpaperProvider: Sendable {
    /// File URL of the wallpaper currently set on `displayID`. Returns
    /// nil for an unknown display, a display with no wallpaper set, or
    /// a transient lookup failure (the workspace may be mid-update).
    func wallpaper(for displayID: UInt32) -> URL?

    /// Set the desktop wallpaper of `displayID` to `url`. Throws if the
    /// display is unknown, the URL is unreadable, or the workspace
    /// rejects the request. Implementations MUST persist the new
    /// wallpaper before returning so a subsequent `wallpaper(for:)`
    /// reflects the change.
    func setWallpaper(for displayID: UInt32, url: URL) throws
}

/// Hermetic test provider — feeds `[displayID: URL]` from an in-memory
/// dictionary or a fixture JSON file `{ "1": "/path/to/wp.jpg", "2": ... }`.
/// Activated by `WDM_TEST_WALLPAPER` env var pointing at the fixture.
/// `setWallpaper` mutates the on-disk fixture so the round-trip is
/// observable from a separate process (tests poll the fixture file).
public final class RecordingWallpaperProvider: WallpaperProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var mappings: [UInt32: URL]
    private let fixtureURL: URL?

    public init(mappings: [UInt32: URL]) {
        self.mappings = mappings
        self.fixtureURL = nil
    }

    public init(fixtureURL: URL) throws {
        let data = try Data(contentsOf: fixtureURL)
        let dict = (try JSONSerialization.jsonObject(with: data) as? [String: String]) ?? [:]
        var m: [UInt32: URL] = [:]
        for (k, v) in dict {
            if let id = UInt32(k) { m[id] = URL(fileURLWithPath: v) }
        }
        self.mappings = m
        self.fixtureURL = fixtureURL
    }

    public func wallpaper(for displayID: UInt32) -> URL? {
        lock.withLock { mappings[displayID] }
    }

    public func setWallpaper(for displayID: UInt32, url: URL) throws {
        lock.withLock { mappings[displayID] = url }
        if let fix = fixtureURL { try writeFixture(to: fix) }
    }

    private func writeFixture(to url: URL) throws {
        let dict = lock.withLock {
            mappings.reduce(into: [String: String]()) { $0["\($1.key)"] = $1.value.path }
        }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}

/// Real macOS provider — looks up the `NSScreen` whose
/// `NSScreenNumber` matches `displayID`, asks `NSWorkspace` for its
/// current wallpaper. Pure public API; no entitlement or TCC dance.
public struct NSWorkspaceWallpaperProvider: WallpaperProvider {
    public init() {}

    public func wallpaper(for displayID: UInt32) -> URL? {
        guard let screen = screen(forDisplayID: displayID) else { return nil }
        return NSWorkspace.shared.desktopImageURL(for: screen)
    }

    public func setWallpaper(for displayID: UInt32, url: URL) throws {
        guard let screen = screen(forDisplayID: displayID) else {
            throw NSError(domain: "WDMSystem.Wallpaper", code: 1,
                          userInfo: [NSLocalizedDescriptionKey:
                            "no NSScreen for display \(displayID)"])
        }
        try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
    }

    private func screen(forDisplayID displayID: UInt32) -> NSScreen? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return NSScreen.screens.first {
            ($0.deviceDescription[key] as? UInt32) == displayID
        }
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

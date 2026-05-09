import Foundation

/// JSON contract sent from Swift → embedded WebKit Stage. Mirrors the
/// `state` shape consumed by `window.wdm.setState(...)` in stage.js.
///
/// **Zoom is intentionally absent** — it's JS-owned state, controlled
/// only by the explicit `+` / `-` buttons and trackpad pinch gestures
/// inside the WebView. Swift must not override it.
public struct StageState: Codable, Equatable, Sendable {
    public let tiles: [StageTilePayload]
    public let selectedID: UInt32?

    public init(tiles: [StageTilePayload], selectedID: UInt32?) {
        self.tiles = tiles
        self.selectedID = selectedID
    }
}

public struct StageTilePayload: Codable, Equatable, Sendable {
    public let id: UInt32
    public let name: String
    public let isMain: Bool
    public let widthPx: Int
    public let heightPx: Int
    public let originX: Int
    public let originY: Int
    public let refreshHz: Int
    /// File-system path of the desktop wallpaper currently set on this
    /// display (or nil if none). Sent to stage.js so each tile renders
    /// the actual screen background instead of a solid placeholder.
    /// `file://` URL prefix is added on the JS side.
    public let wallpaperPath: String?

    public init(id: UInt32, name: String, isMain: Bool,
                widthPx: Int, heightPx: Int,
                originX: Int, originY: Int, refreshHz: Int,
                wallpaperPath: String? = nil) {
        self.id = id; self.name = name; self.isMain = isMain
        self.widthPx = widthPx; self.heightPx = heightPx
        self.originX = originX; self.originY = originY
        self.refreshHz = refreshHz
        self.wallpaperPath = wallpaperPath
    }
}

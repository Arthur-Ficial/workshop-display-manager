import Foundation

/// Pure fit-to-canvas math for the Stage canvas. Given a set of tile rects
/// (display-space pixels) and a target canvas size (canvas-space pixels),
/// returns the scale + offset such that the union bounding box of all tiles
/// is fully visible inside the canvas with `inset` padding on every edge,
/// and the bounding box's centre is at the canvas's centre.
///
/// JS-side mirror lives in `Sources/WDMMac/Resources/stage/stage.js`
/// (`computeLayout`); the two implementations must agree. Tests pin the
/// invariant: every transformed tile rect lies inside the canvas.
public enum StageAutoFit {
    public struct Tile: Equatable, Sendable {
        public let originX: Int
        public let originY: Int
        public let widthPx: Int
        public let heightPx: Int
        public init(originX: Int, originY: Int, widthPx: Int, heightPx: Int) {
            self.originX = originX; self.originY = originY
            self.widthPx = widthPx; self.heightPx = heightPx
        }
    }

    public struct Layout: Equatable, Sendable {
        public let scale: Double
        public let offsetX: Double
        public let offsetY: Double
    }

    public static func fit(
        tiles: [Tile],
        canvasWidth: Double,
        canvasHeight: Double,
        inset: Double
    ) -> Layout {
        guard !tiles.isEmpty else {
            return Layout(scale: 1.0, offsetX: 0.0, offsetY: 0.0)
        }
        let minX = tiles.map { $0.originX }.min()!
        let minY = tiles.map { $0.originY }.min()!
        let maxX = tiles.map { $0.originX + $0.widthPx }.max()!
        let maxY = tiles.map { $0.originY + $0.heightPx }.max()!
        let bbW = Double(maxX - minX)
        let bbH = Double(maxY - minY)
        let innerW = max(canvasWidth - 2 * inset, 1)
        let innerH = max(canvasHeight - 2 * inset, 1)
        let scale = min(innerW / bbW, innerH / bbH)
        let scaledW = bbW * scale
        let scaledH = bbH * scale
        let offsetX = (canvasWidth - scaledW) / 2 - Double(minX) * scale
        let offsetY = (canvasHeight - scaledH) / 2 - Double(minY) * scale
        return Layout(scale: scale, offsetX: offsetX, offsetY: offsetY)
    }
}

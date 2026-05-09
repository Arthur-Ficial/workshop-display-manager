import Testing
@testable import WDMCore

@Suite("StageAutoFit — pure fit-to-canvas math")
struct StageAutoFitTests {

    @Test("Single tile fits and is centered")
    func singleTileCentered() {
        let tiles = [StageAutoFit.Tile(originX: 0, originY: 0, widthPx: 1000, heightPx: 500)]
        let r = StageAutoFit.fit(tiles: tiles, canvasWidth: 800, canvasHeight: 600, inset: 20)
        // canvasW-2*inset = 760; canvasH-2*inset = 560
        // scale = min(760/1000, 560/500) = min(0.76, 1.12) = 0.76
        #expect(abs(r.scale - 0.76) < 1e-6)
        // bbW*scale = 760, centered horizontally → offsetX = (800-760)/2 = 20
        #expect(abs(r.offsetX - 20) < 1e-6)
        // bbH*scale = 380, centered vertically → offsetY = (600-380)/2 = 110
        #expect(abs(r.offsetY - 110) < 1e-6)
    }

    @Test("Two tiles side by side fit and are centered as a group")
    func twoTilesCentered() {
        let tiles = [
            StageAutoFit.Tile(originX: 0, originY: 0, widthPx: 1000, heightPx: 500),
            StageAutoFit.Tile(originX: 1000, originY: 0, widthPx: 1000, heightPx: 500),
        ]
        let r = StageAutoFit.fit(tiles: tiles, canvasWidth: 800, canvasHeight: 600, inset: 20)
        // bbW=2000, bbH=500; inner=760×560; scale = min(0.38, 1.12) = 0.38
        #expect(abs(r.scale - 0.38) < 1e-6)
        // bbW*scale = 760 → offsetX = (800-760)/2 - 0*scale = 20
        #expect(abs(r.offsetX - 20) < 1e-6)
        // bbH*scale = 190 → offsetY = (600-190)/2 = 205
        #expect(abs(r.offsetY - 205) < 1e-6)
    }

    @Test("Negative origins are handled (display arranged to the left of main)")
    func negativeOrigin() {
        let tiles = [
            StageAutoFit.Tile(originX: -1920, originY: 0, widthPx: 1920, heightPx: 1080),
            StageAutoFit.Tile(originX: 0, originY: 0, widthPx: 1920, heightPx: 1080),
        ]
        let r = StageAutoFit.fit(tiles: tiles, canvasWidth: 1000, canvasHeight: 600, inset: 10)
        // bbMinX=-1920, bbW=3840, bbH=1080; inner=980×580
        // scale = min(980/3840, 580/1080) = min(0.255208, 0.537037) ≈ 0.255208
        #expect(abs(r.scale - (980.0/3840.0)) < 1e-6)
        // After applying offset, leftmost tile at x=-1920 should map to >= inset:
        // (-1920) * scale + offsetX should be >= 0 (inside canvas)
        let leftPx = Double(-1920) * r.scale + r.offsetX
        #expect(leftPx >= 0)
        // Rightmost tile (0+1920=1920) at edge:
        let rightPx = Double(1920) * r.scale + r.offsetX
        #expect(rightPx <= 1000)
    }

    @Test("Empty tile set returns identity (scale=1, offset=0)")
    func emptyTiles() {
        let r = StageAutoFit.fit(tiles: [], canvasWidth: 800, canvasHeight: 600, inset: 20)
        #expect(r.scale == 1.0)
        #expect(r.offsetX == 0.0)
        #expect(r.offsetY == 0.0)
    }

    @Test("Result invariant: every tile's transformed rect fits inside the canvas")
    func everyTileFitsInsideCanvas() {
        let tiles = [
            StageAutoFit.Tile(originX: -2560, originY: -1440, widthPx: 2560, heightPx: 1440),
            StageAutoFit.Tile(originX: 0, originY: 0, widthPx: 1920, heightPx: 1080),
            StageAutoFit.Tile(originX: 1920, originY: 0, widthPx: 3840, heightPx: 2160),
        ]
        let canvasW = 1200.0, canvasH = 700.0, inset = 14.0
        let r = StageAutoFit.fit(tiles: tiles, canvasWidth: canvasW, canvasHeight: canvasH, inset: inset)
        for t in tiles {
            let x0 = Double(t.originX) * r.scale + r.offsetX
            let y0 = Double(t.originY) * r.scale + r.offsetY
            let x1 = x0 + Double(t.widthPx) * r.scale
            let y1 = y0 + Double(t.heightPx) * r.scale
            // Every tile rect inside [inset, canvas-inset] (small float slack)
            #expect(x0 >= inset - 1e-6)
            #expect(y0 >= inset - 1e-6)
            #expect(x1 <= canvasW - inset + 1e-6)
            #expect(y1 <= canvasH - inset + 1e-6)
        }
    }

    @Test("Group bounding box is centered in the canvas")
    func bboxIsCentered() {
        let tiles = [
            StageAutoFit.Tile(originX: 0, originY: 0, widthPx: 1920, heightPx: 1080),
            StageAutoFit.Tile(originX: 1920, originY: 0, widthPx: 1920, heightPx: 1080),
        ]
        let canvasW = 1000.0, canvasH = 700.0, inset = 20.0
        let r = StageAutoFit.fit(tiles: tiles, canvasWidth: canvasW, canvasHeight: canvasH, inset: inset)
        // bbW=3840, bbH=1080
        let scaledW = 3840.0 * r.scale
        let scaledH = 1080.0 * r.scale
        // Center of bbox in canvas pixels:
        let bboxCenterX = 0.0 * r.scale + r.offsetX + scaledW / 2
        let bboxCenterY = 0.0 * r.scale + r.offsetY + scaledH / 2
        #expect(abs(bboxCenterX - canvasW / 2) < 1e-6)
        #expect(abs(bboxCenterY - canvasH / 2) < 1e-6)
    }
}

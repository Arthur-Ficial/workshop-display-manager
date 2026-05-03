import Foundation
import Testing
import WDMKit
@testable import WDMWeb

@Suite("WDMWebIndexHandler")
struct WDMWebIndexHandlerTests {
    @Test("renders an SVG rect per display, scaled to a sensible canvas size")
    func renderTwoDisplays() {
        let displays = [
            DisplayInfo(
                id: 1, name: "Built-in", isMain: true, isOnline: true, mirrorSource: nil,
                currentMode: Mode(width: 1470, height: 956, refreshHz: 60),
                origin: Point(x: 0, y: 0), rotationDegrees: 0
            ),
            DisplayInfo(
                id: 2, name: "BenQ", isMain: false, isOnline: true, mirrorSource: nil,
                currentMode: Mode(width: 1920, height: 1080, refreshHz: 75),
                origin: Point(x: 1470, y: 0), rotationDegrees: 0
            ),
        ]
        let html = WDMWebIndexHandler.render(displays: displays)
        #expect(html.contains("<svg"))
        #expect(html.contains("Built-in"))
        #expect(html.contains("BenQ"))
        #expect(html.contains("(MAIN)"))
        #expect(html.contains("1920×1080@75"))
    }

    @Test("computeBounds returns the union extent of every display")
    func bounds() {
        let displays = [
            DisplayInfo(id: 1, name: nil, isMain: true, isOnline: true, mirrorSource: nil,
                        currentMode: Mode(width: 1000, height: 500, refreshHz: 60),
                        origin: Point(x: 0, y: 0), rotationDegrees: 0),
            DisplayInfo(id: 2, name: nil, isMain: false, isOnline: true, mirrorSource: nil,
                        currentMode: Mode(width: 800, height: 600, refreshHz: 60),
                        origin: Point(x: -800, y: 100), rotationDegrees: 0),
        ]
        let b = WDMWebIndexHandler.computeBounds(displays)
        #expect(b.minX == -800)
        #expect(b.minY == 0)
        #expect(b.width == 1800)
        #expect(b.height == 700)
    }

    @Test("escape neutralises HTML metacharacters")
    func escapeMeta() {
        #expect(WDMWebIndexHandler.escape("<a&b>") == "&lt;a&amp;b&gt;")
    }
}

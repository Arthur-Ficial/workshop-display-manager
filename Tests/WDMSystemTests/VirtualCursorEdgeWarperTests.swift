import Testing
import CoreGraphics
@testable import WDMSystem

@Suite("VirtualCursorEdgeWarper — pure edge-detection (issue #7 fallback)")
struct VirtualCursorEdgeWarperTests {

    private let benq    = CGRect(x: 1470, y: 0, width: 1920, height: 1080)
    private let virtual = CGRect(x: 3390, y: 0, width: 1320, height: 2868)

    @Test("cursor at right edge of BenQ (touches virtual) → warp into virtual")
    func rightEdge() {
        // location = (3389, 500) — clamped at BenQ.maxX-1; virtual at minX=3390.
        let pt = VirtualCursorEdgeWarper.warpTarget(
            from: benq, to: virtual, location: CGPoint(x: 3389, y: 500)
        )
        #expect(pt != nil)
        #expect(pt!.x > virtual.minX && pt!.x < virtual.maxX)
        #expect(pt!.y == 500)
    }

    @Test("cursor away from edge → no warp")
    func awayFromEdge() {
        let pt = VirtualCursorEdgeWarper.warpTarget(
            from: benq, to: virtual, location: CGPoint(x: 2000, y: 500)
        )
        #expect(pt == nil)
    }

    @Test("cursor at edge but Y outside virtual.y → no warp")
    func yOutOfRange() {
        // virtual ends at y=2868; if cursor at y=3000 it's outside the
        // overlap region (BenQ y∈[0,1080], virtual y∈[0,2868] — overlap [0,1080)).
        let pt = VirtualCursorEdgeWarper.warpTarget(
            from: benq, to: virtual, location: CGPoint(x: 3389, y: 3000)
        )
        #expect(pt == nil)
    }

    @Test("left-edge case: virtual to LEFT of current display")
    func leftEdge() {
        // Same shapes but virtual on the left, BenQ on the right.
        let leftVirtual = CGRect(x: -1320, y: 0, width: 1320, height: 2868)
        let benqAt0     = CGRect(x: 0,     y: 0, width: 1920, height: 1080)
        let pt = VirtualCursorEdgeWarper.warpTarget(
            from: benqAt0, to: leftVirtual, location: CGPoint(x: 0, y: 500)
        )
        #expect(pt != nil)
        #expect(pt!.x > leftVirtual.minX && pt!.x < leftVirtual.maxX)
    }

    @Test("non-touching displays → no warp even at edge")
    func notTouching() {
        // Virtual is far away, not touching BenQ — gap of 100px.
        let farVirtual = CGRect(x: 3490, y: 0, width: 1320, height: 2868)
        let pt = VirtualCursorEdgeWarper.warpTarget(
            from: benq, to: farVirtual, location: CGPoint(x: 3389, y: 500)
        )
        #expect(pt == nil)
    }
}

import Testing
import CoreGraphics
@testable import WDMSystem

@Suite("CyclicArrangementWarper — pure cyclic edge wrap (no virtual clone)")
struct CyclicArrangementWarperTests {

    // The arrangement is the union of all displays.
    // For the cycle algorithm:
    //   - rightmost = display with max maxX
    //   - leftmost  = display with min minX
    //   - topmost   = display with min minY  (CG's top-left origin)
    //   - bottommost = display with max maxY

    typealias D = CyclicArrangementWarper.Display

    private let builtIn = D(id: 1, bounds: CGRect(x: 0,    y: 0, width: 1470, height: 956))
    private let benq    = D(id: 2, bounds: CGRect(x: 1470, y: 0, width: 1920, height: 1080))

    // MARK: - x-axis

    @Test("right wrap: cursor at rightmost display's right edge → leftmost display's left edge")
    func rightWrap() {
        let pt = CyclicArrangementWarper.cyclicWarpTarget(
            displays: [builtIn, benq],
            location: CGPoint(x: 3389, y: 500)
        )
        #expect(pt != nil)
        #expect(pt!.x >= 0 && pt!.x < 10)  // landed inside built-in (leftmost)
        #expect(pt!.y == 500)
    }

    @Test("left wrap: cursor at leftmost display's left edge → rightmost display's right edge")
    func leftWrap() {
        let pt = CyclicArrangementWarper.cyclicWarpTarget(
            displays: [builtIn, benq],
            location: CGPoint(x: 0, y: 500)
        )
        #expect(pt != nil)
        // Should land just inside BenQ (rightmost), close to its right edge.
        #expect(pt!.x > 3380 && pt!.x < 3390)
        #expect(pt!.y == 500)
    }

    @Test("middle: no wrap — cursor in the middle of an interior display")
    func noWrapInMiddle() {
        let pt = CyclicArrangementWarper.cyclicWarpTarget(
            displays: [builtIn, benq],
            location: CGPoint(x: 700, y: 400)
        )
        #expect(pt == nil)
    }

    @Test("interior edge between two adjacent displays: no wrap (native handles it)")
    func noWrapAtInteriorEdge() {
        // Edge between built-in and BenQ at x=1470 — that's a native crossing point,
        // not an arrangement extreme.
        let pt = CyclicArrangementWarper.cyclicWarpTarget(
            displays: [builtIn, benq],
            location: CGPoint(x: 1469, y: 400)
        )
        #expect(pt == nil)
    }

    // MARK: - y-axis

    @Test("top wrap: cursor at topmost display's top edge → bottommost display's bottom edge")
    func topWrap() {
        // Two displays stacked vertically: top at (0,0), bottom at (0,956).
        let top    = D(id: 1, bounds: CGRect(x: 0, y: 0,    width: 1470, height: 956))
        let bottom = D(id: 2, bounds: CGRect(x: 0, y: 956,  width: 1470, height: 1080))
        let pt = CyclicArrangementWarper.cyclicWarpTarget(
            displays: [top, bottom],
            location: CGPoint(x: 700, y: 0)
        )
        #expect(pt != nil)
        #expect(pt!.y > 2025 && pt!.y < 2036)  // just inside bottom's bottom edge
        #expect(pt!.x == 700)
    }

    @Test("bottom wrap: cursor at bottommost display's bottom edge → topmost display's top edge")
    func bottomWrap() {
        let top    = D(id: 1, bounds: CGRect(x: 0, y: 0,    width: 1470, height: 956))
        let bottom = D(id: 2, bounds: CGRect(x: 0, y: 956,  width: 1470, height: 1080))
        let pt = CyclicArrangementWarper.cyclicWarpTarget(
            displays: [top, bottom],
            location: CGPoint(x: 700, y: 2035)  // bottom's bottom-1
        )
        #expect(pt != nil)
        #expect(pt!.y >= 0 && pt!.y < 10)  // top of topmost
        #expect(pt!.x == 700)
    }

    // MARK: - geometry edge cases

    @Test("empty display list → no warp")
    func empty() {
        #expect(CyclicArrangementWarper.cyclicWarpTarget(
            displays: [], location: CGPoint(x: 100, y: 100)
        ) == nil)
    }

    @Test("single display → no wrap (degenerate cycle)")
    func single() {
        // No "opposite extreme" to wrap to.
        #expect(CyclicArrangementWarper.cyclicWarpTarget(
            displays: [builtIn], location: CGPoint(x: 1469, y: 500)
        ) == nil)
    }

    @Test("y outside the destination's row → no wrap (would land off-screen)")
    func yOutOfDestRange() {
        // built-in is 956 tall, BenQ is 1080. Cursor at y=1050 is on BenQ but
        // outside built-in's y range. Wrapping right→left would land at y=1050
        // which isn't in built-in. Reject.
        let pt = CyclicArrangementWarper.cyclicWarpTarget(
            displays: [builtIn, benq],
            location: CGPoint(x: 3389, y: 1050)
        )
        #expect(pt == nil)
    }

    @Test("three-display arrangement: extremes determined globally not pairwise")
    func threeDisplays() {
        let extra = D(id: 3, bounds: CGRect(x: 3390, y: 0, width: 1280, height: 720))
        let displays = [builtIn, benq, extra]
        // rightmost is now extra (maxX = 4670). Cursor at extra's right edge wraps to built-in.
        let pt = CyclicArrangementWarper.cyclicWarpTarget(
            displays: displays,
            location: CGPoint(x: 4669, y: 400)
        )
        #expect(pt != nil)
        #expect(pt!.x >= 0 && pt!.x < 10)  // built-in (leftmost)
    }
}

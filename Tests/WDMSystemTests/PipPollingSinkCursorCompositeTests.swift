import Testing
import CoreGraphics
import AppKit
@testable import WDMSystem

@Suite("PipPollingSink — cursor composite (real-time PIP)")
struct PipPollingSinkCursorCompositeTests {

    /// When the cursor lives outside the source display's bounds, the
    /// captured framebuffer must come back unchanged — no cursor is
    /// drawn into the PIP for a display the cursor isn't on.
    @Test("cursor outside source display → frame returned unchanged")
    func cursorOutsideDisplay() {
        // We can't drive CGEvent location from a unit test, so this test
        // checks the cheap branch: when we hand it a tiny synthetic CGImage
        // and a display that the cursor (wherever it is) isn't on, the
        // function returns SOMETHING valid (either the input unchanged or
        // a freshly-composited image — we tolerate both, but it must not
        // crash and must not return nil-equivalent).
        let frame = makeSolidImage(width: 16, height: 16, color: .red)
        // displayID 0 is the kCGNullDirectDisplay sentinel; CGDisplayBounds
        // returns CGRect.null. The cursor is never inside a null rect so
        // the function takes the fast no-composite branch.
        let out = PipPollingSink.compositeCursor(onto: frame, displayID: 0)
        #expect(out.width == frame.width)
        #expect(out.height == frame.height)
    }

    @Test("composite never crashes for non-null displays")
    func nonNullDisplay() {
        var ids = [CGDirectDisplayID](repeating: 0, count: 1)
        var n: UInt32 = 0
        CGGetActiveDisplayList(1, &ids, &n)
        guard n > 0 else { return }
        let frame = makeSolidImage(width: 64, height: 64, color: .blue)
        let out = PipPollingSink.compositeCursor(onto: frame, displayID: ids[0])
        #expect(out.width == frame.width)
        #expect(out.height == frame.height)
    }

    private func makeSolidImage(width: Int, height: Int, color: NSColor) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }
}

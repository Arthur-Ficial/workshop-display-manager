import Foundation
import CoreGraphics
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController cursorWrap")
struct WDMControllerCursorWrapTests {
    @Test("cursorWrap warps the cursor to the leftmost display when stuck on right edge")
    func warpsRightToLeft() throws {
        let displays = [
            CyclicArrangementWarper.Display(id: 1, bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            CyclicArrangementWarper.Display(id: 2, bounds: CGRect(x: 1920, y: 0, width: 1920, height: 1080)),
        ]
        // Three consecutive samples at the rightmost edge → triggers a warp.
        let stuck = CGPoint(x: 1920 + 1920 - 1, y: 540)
        let io = RecordingCursorIO(
            displays: displays,
            locations: [stuck, stuck, stuck]
        )
        let plan = WDMController.CursorWrapPlan(
            durationMs: nil, intervalMs: 1, consecutive: 3
        )
        // Stop after the first warp lands so the test is deterministic.
        try WDMController.cursorWrap(plan: plan, io: io, shouldStop: { !io.recordedWarps().isEmpty })
        let warps = io.recordedWarps()
        #expect(warps.count >= 1)
        // Wraps to the leftmost display interior.
        #expect(warps[0].x == 8) // default inset
    }
}

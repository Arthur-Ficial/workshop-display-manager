import Foundation
import CoreGraphics
import WDMSystem

extension WDMController {
    public struct CursorWrapPlan: Equatable, Sendable {
        public let durationMs: Int?
        public let intervalMs: Int
        public let consecutive: Int
        public let jitterPx: CGFloat
        public let edgeSlop: CGFloat
        public let inset: CGFloat

        public init(
            durationMs: Int? = nil,
            intervalMs: Int = 16,
            consecutive: Int = 3,
            jitterPx: CGFloat = 6,
            edgeSlop: CGFloat = 1,
            inset: CGFloat = 8
        ) {
            self.durationMs = durationMs
            self.intervalMs = intervalMs
            self.consecutive = consecutive
            self.jitterPx = jitterPx
            self.edgeSlop = edgeSlop
            self.inset = inset
        }
    }

    /// Cyclic cursor wrap across the active arrangement. Polls the cursor at
    /// `intervalMs` and warps when the cursor has been at an arrangement
    /// extremum for `consecutive` samples (with jitter tolerance). Stops when
    /// `durationMs` elapses or `shouldStop` returns true.
    public static func cursorWrap(
        plan: CursorWrapPlan,
        io: CursorIO,
        shouldStop: () -> Bool = { false }
    ) throws {
        let deadline: Date? = plan.durationMs.map {
            Date(timeIntervalSinceNow: TimeInterval($0) / 1000.0)
        }
        var atEdgeCount = 0
        var lastLoc: CGPoint = .zero
        while !shouldStop() {
            if let deadline, Date() >= deadline { break }
            let loc = io.currentLocation()
            let target = CyclicArrangementWarper.cyclicWarpTarget(
                displays: io.activeDisplays(), location: loc,
                edgeSlop: plan.edgeSlop, inset: plan.inset
            )
            let jitter = abs(loc.x - lastLoc.x) <= plan.jitterPx
                && abs(loc.y - lastLoc.y) <= plan.jitterPx
            if let t = target, jitter {
                atEdgeCount += 1
                if atEdgeCount >= plan.consecutive {
                    io.warp(to: t)
                    atEdgeCount = 0
                    lastLoc = t
                    Thread.sleep(forTimeInterval: TimeInterval(plan.intervalMs) * 0.005)
                    continue
                }
            } else {
                atEdgeCount = 0
            }
            lastLoc = loc
            Thread.sleep(forTimeInterval: TimeInterval(plan.intervalMs) / 1000.0)
        }
    }
}

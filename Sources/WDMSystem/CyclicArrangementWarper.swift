import CoreGraphics
import Foundation

/// Cyclic cursor wrap across the full display arrangement, **without**
/// requiring a virtual clone display sitting at the opposite extreme.
///
/// Algorithm: when the cursor is hugging the rightmost-display's right
/// edge (i.e. the arrangement's rightmost extremum), warp it to the
/// leftmost-display's left edge — and symmetrically for left/top/bottom.
///
/// All four wraps require the destination's other-axis range to overlap
/// the source's, so the cursor doesn't land off-screen.
///
/// This is OS-policy-aware: WindowServer clamps the cursor at the active
/// arrangement's bounding union, so a real HID push past the rightmost
/// edge stops at `(rightmost.maxX - 1, y)`. We detect that and warp.
///
/// Pure-physics module — every decision is a function of `(displays,
/// location)`. The wrapping policy generalises to any number of displays
/// and any arrangement layout because it only consults the global
/// extrema (leftmost / rightmost / topmost / bottommost picks) which are
/// well-defined for any non-empty display set.
public enum CyclicArrangementWarper {

    public struct Display: Equatable, Sendable {
        public let id: UInt32
        public let bounds: CGRect
        public init(id: UInt32, bounds: CGRect) {
            self.id = id
            self.bounds = bounds
        }
    }

    /// Pure helper: given the active-display set and the current cursor
    /// location, decide if the cursor is hugging an arrangement-extremum
    /// edge and return the cyclic-wrap destination point. Nil means the
    /// cursor isn't at an extremum, or the destination row/column doesn't
    /// overlap.
    public static func cyclicWarpTarget(
        displays: [Display],
        location: CGPoint,
        edgeSlop: CGFloat = 1,
        inset: CGFloat = 2
    ) -> CGPoint? {
        guard displays.count >= 2 else { return nil }

        let leftmost   = displays.min { $0.bounds.minX < $1.bounds.minX }!
        let rightmost  = displays.max { $0.bounds.maxX < $1.bounds.maxX }!
        let topmost    = displays.min { $0.bounds.minY < $1.bounds.minY }!
        let bottommost = displays.max { $0.bounds.maxY < $1.bounds.maxY }!

        // x-axis wraps require a horizontal extreme pair AND y-overlap
        // between the source row and destination row.
        if leftmost.id != rightmost.id {
            // Right wrap: cursor at rightmost's right edge → leftmost's interior left.
            if abs(location.x - (rightmost.bounds.maxX - 1)) <= edgeSlop,
               yOverlaps(location.y, source: rightmost.bounds, dest: leftmost.bounds) {
                return CGPoint(x: leftmost.bounds.minX + inset, y: location.y)
            }
            // Left wrap: cursor at leftmost's left edge → rightmost's interior right.
            if abs(location.x - leftmost.bounds.minX) <= edgeSlop,
               yOverlaps(location.y, source: leftmost.bounds, dest: rightmost.bounds) {
                return CGPoint(x: rightmost.bounds.maxX - inset, y: location.y)
            }
        }

        if topmost.id != bottommost.id {
            // Top wrap: cursor at topmost's top edge → bottommost's interior bottom.
            if abs(location.y - topmost.bounds.minY) <= edgeSlop,
               xOverlaps(location.x, source: topmost.bounds, dest: bottommost.bounds) {
                return CGPoint(x: location.x, y: bottommost.bounds.maxY - inset)
            }
            // Bottom wrap: cursor at bottommost's bottom edge → topmost's interior top.
            if abs(location.y - (bottommost.bounds.maxY - 1)) <= edgeSlop,
               xOverlaps(location.x, source: bottommost.bounds, dest: topmost.bounds) {
                return CGPoint(x: location.x, y: topmost.bounds.minY + inset)
            }
        }

        return nil
    }

    private static func yOverlaps(_ y: CGFloat, source: CGRect, dest: CGRect) -> Bool {
        y >= max(source.minY, dest.minY) && y < min(source.maxY, dest.maxY)
    }

    private static func xOverlaps(_ x: CGFloat, source: CGRect, dest: CGRect) -> Bool {
        x >= max(source.minX, dest.minX) && x < min(source.maxX, dest.maxX)
    }
}

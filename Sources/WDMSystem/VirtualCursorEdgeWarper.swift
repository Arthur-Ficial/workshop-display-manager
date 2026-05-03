import CoreGraphics
import Foundation

/// Fallback for the cursor edge portal: a 60Hz poller that detects when
/// the cursor is "stuck" at a display edge that touches the virtual display
/// (i.e., the user is actively pushing the mouse past the boundary but
/// WindowServer is clamping it) and warps the cursor across.
///
/// Why this exists: `.cgSessionEventTap` does receive HID-driven mouseMoved
/// events, but WindowServer clamps the cursor to the union of active-display
/// bounds *before* forwarding the event, so over-the-edge motion vanishes
/// before the event tap can rewrite it. Polling cursor position and detecting
/// "held at edge for ≥ 3 consecutive samples" is the workaround multi-display
/// tools (BetterDisplay, displayplacer plugins) use, and it is robust under
/// macOS's HID clamping.
final class VirtualCursorEdgeWarper: @unchecked Sendable {
    private let displayID: CGDirectDisplayID
    private let pollIntervalMs: Int
    private let consecutiveAtEdgeRequired: Int
    private let lock = NSLock()
    private var stopRequested = false
    nonisolated(unsafe) private var thread: Thread?

    init(
        displayID: CGDirectDisplayID,
        pollIntervalMs: Int = 16,
        consecutiveAtEdgeRequired: Int = 3
    ) {
        self.displayID = displayID
        self.pollIntervalMs = pollIntervalMs
        self.consecutiveAtEdgeRequired = consecutiveAtEdgeRequired
    }

    func start() {
        let t = Thread { [weak self] in self?.loop() }
        t.qualityOfService = .userInteractive
        t.name = "wdm.virtual.cursor.warper"
        t.start()
        thread = t
    }

    func stop() {
        lock.withLock { stopRequested = true }
        thread = nil
    }

    private func loop() {
        var atEdgeCount = 0
        var lastLoc: CGPoint = .zero
        let interval = TimeInterval(pollIntervalMs) / 1000.0
        // Real HID input jitters by 1-2px even when the user's finger is
        // pressed against the trackpad edge — exact-equality breaks the
        // detector. Tolerance: any movement within `jitterPx` counts as
        // "still hugging the edge".
        let jitterPx: CGFloat = 3
        while !lock.withLock({ stopRequested }) {
            let loc = CGEvent(source: nil)?.location ?? .zero
            let displays = Self.activeDisplays()
            guard let virtual = displays.first(where: { $0.id == displayID }) else {
                Thread.sleep(forTimeInterval: interval)
                continue
            }
            // We only act when the cursor is on a display OTHER than the virtual,
            // hugging the boundary that touches the virtual.
            guard let current = displays.first(where: {
                $0.id != displayID && $0.bounds.contains(loc)
            }) else {
                atEdgeCount = 0
                lastLoc = loc
                Thread.sleep(forTimeInterval: interval)
                continue
            }
            let jitter = abs(loc.x - lastLoc.x) <= jitterPx
                && abs(loc.y - lastLoc.y) <= jitterPx
            // Compute the union rect of every active display so wrap-around
            // detection knows where the arrangement extremes are.
            let arrangement = displays
                .map(\.bounds)
                .reduce(CGRect.null) { $0.union($1) }
            if let target = Self.warpTarget(
                from: current.bounds, to: virtual.bounds,
                location: loc, arrangement: arrangement
            ), jitter {
                atEdgeCount += 1
                if atEdgeCount >= consecutiveAtEdgeRequired {
                    CGWarpMouseCursorPosition(target)
                    atEdgeCount = 0
                }
            } else {
                atEdgeCount = 0
            }
            lastLoc = loc
            Thread.sleep(forTimeInterval: interval)
        }
    }

    /// Pure helper exposed for unit tests. Returns the warp destination
    /// inside `virtual` if `location` is hugging an edge of `current`
    /// that either touches `virtual` directly OR makes `virtual` the
    /// "opposite extremum" of the arrangement — i.e., wrap-around topology.
    /// Pass the union of all active-display extremes via `arrangement`
    /// so the wrap variant can fire when current/virtual aren't adjacent.
    static func warpTarget(
        from current: CGRect,
        to virtual: CGRect,
        location: CGPoint,
        arrangement: CGRect? = nil
    ) -> CGPoint? {
        if let direct = adjacentWarp(from: current, to: virtual, location: location) {
            return direct
        }
        if let arr = arrangement,
           let wrap = wrapAroundWarp(
                from: current, to: virtual, location: location, arrangement: arr
           ) {
            return wrap
        }
        return nil
    }

    private static func adjacentWarp(
        from current: CGRect,
        to virtual: CGRect,
        location: CGPoint
    ) -> CGPoint? {
        let edgeSlop: CGFloat = 1
        let inset: CGFloat = 2
        // right edge of current touches left edge of virtual
        if abs(location.x - (current.maxX - 1)) <= edgeSlop,
           abs(virtual.minX - current.maxX) <= edgeSlop,
           location.y >= max(current.minY, virtual.minY),
           location.y < min(current.maxY, virtual.maxY) {
            return CGPoint(x: virtual.minX + inset, y: location.y)
        }
        // left edge of current touches right edge of virtual
        if abs(location.x - current.minX) <= edgeSlop,
           abs(current.minX - virtual.maxX) <= edgeSlop,
           location.y >= max(current.minY, virtual.minY),
           location.y < min(current.maxY, virtual.maxY) {
            return CGPoint(x: virtual.maxX - inset, y: location.y)
        }
        // bottom edge of current touches top edge of virtual
        if abs(location.y - (current.maxY - 1)) <= edgeSlop,
           abs(virtual.minY - current.maxY) <= edgeSlop,
           location.x >= max(current.minX, virtual.minX),
           location.x < min(current.maxX, virtual.maxX) {
            return CGPoint(x: location.x, y: virtual.minY + inset)
        }
        // top edge of current touches bottom edge of virtual
        if abs(location.y - current.minY) <= edgeSlop,
           abs(current.minY - virtual.maxY) <= edgeSlop,
           location.x >= max(current.minX, virtual.minX),
           location.x < min(current.maxX, virtual.maxX) {
            return CGPoint(x: location.x, y: virtual.maxY - inset)
        }
        return nil
    }

    /// Wrap-around warp: cursor pushed past the arrangement's outermost
    /// edge wraps to a virtual sitting at the opposite extremum, even if
    /// they aren't directly adjacent. Triggers only when:
    ///   - location is hugging the rightmost edge of an arrangement
    ///     where the virtual is at the leftmost extreme (or vice-versa);
    ///   - y-overlap exists between current and virtual.
    static func wrapAroundWarp(
        from current: CGRect,
        to virtual: CGRect,
        location: CGPoint,
        arrangement: CGRect
    ) -> CGPoint? {
        let edgeSlop: CGFloat = 2
        let inset: CGFloat = 2
        // right-edge wrap: current is at the right extreme, virtual at the left.
        if abs(current.maxX - arrangement.maxX) <= edgeSlop,
           abs(virtual.minX - arrangement.minX) <= edgeSlop,
           abs(location.x - (current.maxX - 1)) <= edgeSlop,
           location.y >= max(current.minY, virtual.minY),
           location.y < min(current.maxY, virtual.maxY) {
            return CGPoint(x: virtual.minX + inset, y: location.y)
        }
        // left-edge wrap: current is at the left extreme, virtual at the right.
        if abs(current.minX - arrangement.minX) <= edgeSlop,
           abs(virtual.maxX - arrangement.maxX) <= edgeSlop,
           abs(location.x - current.minX) <= edgeSlop,
           location.y >= max(current.minY, virtual.minY),
           location.y < min(current.maxY, virtual.maxY) {
            return CGPoint(x: virtual.maxX - inset, y: location.y)
        }
        return nil
    }

    private struct ActiveDisplay {
        let id: CGDirectDisplayID
        let bounds: CGRect
    }

    private static func activeDisplays() -> [ActiveDisplay] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map {
            ActiveDisplay(id: $0, bounds: CGDisplayBounds($0))
        }
    }
}

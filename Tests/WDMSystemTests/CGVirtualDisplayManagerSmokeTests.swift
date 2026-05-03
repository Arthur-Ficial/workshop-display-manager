import Testing
import Foundation
import CoreGraphics
@testable import WDMCore
@testable import WDMSystem

/// Real-hardware smoke test for `CGVirtualDisplayManager`. Verifies that
/// the SPI actually creates a display visible to public CG enumeration on
/// THIS machine (macOS 26.x, Apple Silicon), and that the display vanishes
/// when the manager returns. Gated by `WDM_REAL_HARDWARE=1` to keep
/// `swift test` hermetic by default.
@Suite("CGVirtualDisplayManager (real hardware, gated)",
       .enabled(if: ProcessInfo.processInfo.environment["WDM_REAL_HARDWARE"] == "1"))
struct CGVirtualDisplayManagerSmokeTests {

    private func activeDisplayCount() -> UInt32 {
        var n: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &n)
        return n
    }

    private func activeDisplayIDs() -> [CGDirectDisplayID] {
        let n = activeDisplayCount()
        var ids = Array<CGDirectDisplayID>(repeating: 0, count: Int(n))
        var count: UInt32 = n
        CGGetActiveDisplayList(n, &ids, &count)
        return ids
    }

    @Test("creates a virtual display that appears in CGGetActiveDisplayList, then tears it down")
    func roundTrip() async throws {
        let baselineIDs = Set(activeDisplayIDs())
        let baseline = UInt32(baselineIDs.count)
        let baselineBounds = baselineIDs.map { CGDisplayBounds($0) }
        let mgr = CGVirtualDisplayManager()
        let spec = VirtualDisplaySpec(
            name: "wdm smoke", width: 1920, height: 1080, refreshHz: 60,
            hiDPI: true, widthMM: 600, heightMM: 340
        )

        // Run the manager in a detached task with a 1.5s lifetime; while it's
        // alive, poll the active-display list and assert the count grew by 1.
        let task = Task.detached {
            try mgr.run(spec: spec, durationMs: 1500)
        }

        // Poll up to 1s for the new display to register.
        var newID: CGDirectDisplayID?
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 50_000_000)
            let added = activeDisplayIDs().filter { !baselineIDs.contains($0) }
            if let id = added.first { newID = id; break }
        }
        #expect(newID != nil, "active display count did not grow within 1s of CGVirtualDisplayManager.run")
        if let id = newID {
            let virtualBounds = CGDisplayBounds(id)
            #expect(
                baselineBounds.contains {
                    VirtualCursorPortalRouter.sharesEdge(virtualBounds, $0)
                },
                "new virtual display did not share an edge with any existing display"
            )
            try await verifyPortalMovesCursor(
                targetID: id,
                targetBounds: virtualBounds,
                baselineBounds: baselineBounds
            )
        }

        _ = try await task.value

        // After teardown the count should drop back. Allow a brief settle.
        var settled = false
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 50_000_000)
            if activeDisplayCount() == baseline { settled = true; break }
        }
        #expect(settled, "active display count did not return to baseline within 1s of teardown")
    }

    private func verifyPortalMovesCursor(
        targetID: CGDirectDisplayID,
        targetBounds: CGRect,
        baselineBounds: [CGRect]
    ) async throws {
        let original = CGEvent(source: nil)?.location ?? .zero
        defer { _ = CGWarpMouseCursorPosition(original) }
        guard let crossing = crossingPoint(targetBounds: targetBounds, baselineBounds: baselineBounds) else {
            Issue.record("could not find shared-edge crossing point for virtual display")
            return
        }
        _ = CGWarpMouseCursorPosition(crossing.location)
        try await Task.sleep(nanoseconds: 100_000_000)
        postMouseDelta(at: crossing.location, delta: crossing.delta)
        try await Task.sleep(nanoseconds: 250_000_000)
        let after = CGEvent(source: nil)?.location ?? .zero
        #expect(displays(containing: after).contains(targetID))
    }

    private func crossingPoint(
        targetBounds: CGRect,
        baselineBounds: [CGRect]
    ) -> (location: CGPoint, delta: CGVector)? {
        for bounds in baselineBounds {
            let overlapMinY = max(bounds.minY, targetBounds.minY)
            let overlapMaxY = min(bounds.maxY, targetBounds.maxY)
            let midY = (overlapMinY + overlapMaxY) / 2
            if abs(bounds.minX - targetBounds.maxX) <= 1 {
                return (CGPoint(x: bounds.minX, y: midY), CGVector(dx: -20, dy: 0))
            }
            if abs(bounds.maxX - targetBounds.minX) <= 1 {
                return (CGPoint(x: bounds.maxX - 1, y: midY), CGVector(dx: 20, dy: 0))
            }
        }
        return nil
    }

    private func postMouseDelta(at location: CGPoint, delta: CGVector) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: location,
            mouseButton: .left
        ) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(delta.dx.rounded()))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(delta.dy.rounded()))
        event.post(tap: .cghidEventTap)
    }

    private func displays(containing point: CGPoint) -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        guard CGGetDisplaysWithPoint(point, 8, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }
}

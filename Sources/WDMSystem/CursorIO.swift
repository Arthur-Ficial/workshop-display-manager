import CoreGraphics
import Foundation

/// Side-effect protocol behind `wdm cursor-wrap`. Real impl polls the cursor
/// via `CGEvent` and warps via `CGWarpMouseCursorPosition`. Recording impl
/// drives a deterministic sequence for hermetic tests.
public protocol CursorIO: Sendable {
    func currentLocation() -> CGPoint
    func warp(to point: CGPoint)
    func activeDisplays() -> [CyclicArrangementWarper.Display]
}

public final class RealCursorIO: CursorIO, @unchecked Sendable {
    public init() {}

    public func currentLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    public func warp(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
    }

    public func activeDisplays() -> [CyclicArrangementWarper.Display] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map {
            CyclicArrangementWarper.Display(id: $0, bounds: CGDisplayBounds($0))
        }
    }
}

/// Recording impl. Returns the configured `locations` in order (cycling once
/// exhausted) and records every warp call to an in-memory log. Pure for tests.
public final class RecordingCursorIO: CursorIO, @unchecked Sendable {
    public let displays: [CyclicArrangementWarper.Display]
    private let locations: [CGPoint]
    private let lock = NSLock()
    private var idx: Int = 0
    private var warps: [CGPoint] = []

    public init(
        displays: [CyclicArrangementWarper.Display],
        locations: [CGPoint]
    ) {
        self.displays = displays
        self.locations = locations
    }

    public func currentLocation() -> CGPoint {
        lock.withLock {
            guard !locations.isEmpty else { return .zero }
            let v = locations[idx % locations.count]
            idx += 1
            return v
        }
    }

    public func warp(to point: CGPoint) {
        lock.withLock { warps.append(point) }
    }

    public func activeDisplays() -> [CyclicArrangementWarper.Display] { displays }

    public func recordedWarps() -> [CGPoint] { lock.withLock { warps } }
}

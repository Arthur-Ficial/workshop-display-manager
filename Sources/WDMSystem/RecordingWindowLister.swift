import Foundation

/// Hermetic test impl. Returns a fixed deterministic 2-window list whose
/// `x,y` is set to the requested display bounds origin so the e2e test can
/// verify the display selector was honored.
public final class RecordingWindowLister: WindowLister, @unchecked Sendable {
    public init() {}

    public func windows(onDisplay bounds: CGRect) throws -> [WindowInfo] {
        let baseX = Int(bounds.origin.x)
        let baseY = Int(bounds.origin.y)
        return [
            WindowInfo(
                owner: "TestApp", title: "Window A", pid: 1234,
                x: baseX, y: baseY, width: 800, height: 600
            ),
            WindowInfo(
                owner: "OtherApp", title: "Window B", pid: 1235,
                x: baseX + 100, y: baseY + 100, width: 400, height: 300
            ),
        ]
    }
}

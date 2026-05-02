import Foundation
import CoreGraphics

/// Real `WindowLister` backed by `CGWindowListCopyWindowInfo`. Returns
/// every on-screen window whose frame intersects the given display bounds.
public final class CGWindowLister: WindowLister, @unchecked Sendable {
    public init() {}

    public func windows(onDisplay bounds: CGRect) throws -> [WindowInfo] {
        let listOpts = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let arr = CGWindowListCopyWindowInfo(listOpts, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var out: [WindowInfo] = []
        for info in arr {
            guard let bdict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let pid = info[kCGWindowOwnerPID as String] as? Int32 else { continue }
            let frame = CGRect(
                x: bdict["X"] ?? 0, y: bdict["Y"] ?? 0,
                width: bdict["Width"] ?? 0, height: bdict["Height"] ?? 0
            )
            guard frame.intersects(bounds), frame.width > 1, frame.height > 1 else { continue }
            let owner = (info[kCGWindowOwnerName as String] as? String) ?? ""
            let title = (info[kCGWindowName as String] as? String) ?? ""
            out.append(WindowInfo(
                owner: owner, title: title, pid: pid,
                x: Int(frame.origin.x), y: Int(frame.origin.y),
                width: Int(frame.width), height: Int(frame.height)
            ))
        }
        return out
    }
}

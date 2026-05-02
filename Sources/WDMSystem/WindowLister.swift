import Foundation

/// Lists currently-on-screen windows and reports their bounds + owner.
/// Real impl wraps `CGWindowListCopyWindowInfo`. Recording impl returns a
/// fixed list for hermetic e2e tests.
public protocol WindowLister: Sendable {
    func windows(onDisplay bounds: CGRect) throws -> [WindowInfo]
}

public struct WindowInfo: Sendable, Codable, Equatable, Hashable {
    public let owner: String
    public let title: String
    public let pid: Int32
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(owner: String, title: String, pid: Int32, x: Int, y: Int, width: Int, height: Int) {
        self.owner = owner
        self.title = title
        self.pid = pid
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

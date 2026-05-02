import Foundation

/// Specification for a software-backed virtual display created via the
/// CoreGraphics SPI in `WDMSystem.CGVirtualDisplayManager`. Pure value type —
/// no I/O, no Apple frameworks beyond Foundation.
public struct VirtualDisplaySpec: Sendable, Codable, Equatable, Hashable {
    public let name: String
    public let width: Int
    public let height: Int
    public let refreshHz: Int
    public let hiDPI: Bool
    public let widthMM: Int
    public let heightMM: Int

    public init(
        name: String,
        width: Int, height: Int, refreshHz: Int,
        hiDPI: Bool,
        widthMM: Int, heightMM: Int
    ) {
        self.name = name
        self.width = width
        self.height = height
        self.refreshHz = refreshHz
        self.hiDPI = hiDPI
        self.widthMM = widthMM
        self.heightMM = heightMM
    }

    /// Sane workshop default: 1920×1080 @ 60Hz, HiDPI on, ~24-inch 16:9 panel.
    public static func defaultSpec(name: String) -> VirtualDisplaySpec {
        VirtualDisplaySpec(
            name: name,
            width: 1920, height: 1080, refreshHz: 60,
            hiDPI: true,
            widthMM: 600, heightMM: 340
        )
    }

    /// Parse a `WxH@Hz` token into its components. Returns nil for any
    /// malformed input or non-positive integer.
    public static func parseMode(_ token: String) -> (width: Int, height: Int, refreshHz: Int)? {
        guard let atIdx = token.firstIndex(of: "@") else { return nil }
        let sizePart = String(token[..<atIdx])
        let hzPart = String(token[token.index(after: atIdx)...])
        guard let size = parseSize(sizePart),
              let hz = Int(hzPart), hz > 0 else { return nil }
        return (size.width, size.height, hz)
    }

    /// Parse a `WxH` token into its components. Returns nil for any
    /// malformed input or non-positive integer.
    public static func parseSize(_ token: String) -> (width: Int, height: Int)? {
        let parts = token.split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let w = Int(parts[0]), w > 0,
              let h = Int(parts[1]), h > 0 else { return nil }
        return (w, h)
    }
}

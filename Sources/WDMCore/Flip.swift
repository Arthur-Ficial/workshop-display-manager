import Foundation

/// Per-display image flip, independent of `rotationDegrees`.
/// Encodes whether the framebuffer is mirrored across the X axis (vertical
/// flip), the Y axis (horizontal flip), neither, or both.
public enum Flip: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case none
    case horizontal
    case vertical
    case both

    /// Parse a CLI token. Accepts canonical names and short aliases
    /// (`h`, `v`, `hv`, `vh`, `off`). Returns nil for any other input.
    public static func parse(_ token: String) -> Flip? {
        switch token {
        case "none", "off": return Flip.none
        case "horizontal", "h": return .horizontal
        case "vertical", "v": return .vertical
        case "both", "hv", "vh": return .both
        default: return nil
        }
    }

    /// Whether the framebuffer is inverted along the X axis (left↔right swap).
    public var invertsX: Bool {
        switch self {
        case .horizontal, .both: return true
        case .none, .vertical:  return false
        }
    }

    /// Whether the framebuffer is inverted along the Y axis (top↔bottom swap).
    public var invertsY: Bool {
        switch self {
        case .vertical, .both: return true
        case .none, .horizontal: return false
        }
    }
}

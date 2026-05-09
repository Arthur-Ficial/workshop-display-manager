import Foundation

/// Combinable-toggle math for flip controls. Pure value-typed — no I/O,
/// no state. Single source of truth for "select H while V is on → both".
extension Flip {
    /// Combinable toggle: clicking "—" clears all; clicking H toggles
    /// the H bit while preserving V; clicking V toggles V while
    /// preserving H. `.both` is not a clickable segment — passing it
    /// returns `.none` defensively.
    public func toggling(clicked: Flip) -> Flip {
        switch clicked {
        case .none: return .none
        case .horizontal:
            switch self {
            case .none:       return .horizontal
            case .horizontal: return .none
            case .vertical:   return .both
            case .both:       return .vertical
            }
        case .vertical:
            switch self {
            case .none:       return .vertical
            case .vertical:   return .none
            case .horizontal: return .both
            case .both:       return .horizontal
            }
        case .both:
            return .none
        }
    }

    /// Per-segment selected predicate for flip controls. `.none`
    /// lights only when the current flip is `.none`. `.horizontal`
    /// lights for `.horizontal` AND `.both` (because `.both` carries
    /// the H axis). `.vertical` lights for `.vertical` AND `.both`.
    public func hasAxis(_ segment: Flip) -> Bool {
        switch segment {
        case .none:       return self == .none
        case .horizontal: return self == .horizontal || self == .both
        case .vertical:   return self == .vertical || self == .both
        case .both:       return false
        }
    }
}

import SwiftUI

/// Subtle translucent fill used for inner panels in the dark theme. Sits
/// on top of the window's NSVisualEffectView (.sidebar) backdrop. NOT a
/// .glassEffect (those are reserved for floating cards like buttons).
public struct PanelBackground: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double
    public init(cornerRadius: CGFloat = 8, opacity: Double = 0.06) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }
    public func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(opacity))
        }
    }
}

extension View {
    /// `.panel()` — gives a view the standard subtle inner-panel fill.
    public func panel(cornerRadius: CGFloat = 8, opacity: Double = 0.06) -> some View {
        modifier(PanelBackground(cornerRadius: cornerRadius, opacity: opacity))
    }
}

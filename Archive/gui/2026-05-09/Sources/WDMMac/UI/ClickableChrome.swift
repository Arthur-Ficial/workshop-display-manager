import SwiftUI

/// One source of truth for "this is a clickable surface". Every clickable
/// chrome in the app gets the same idle outline + selected accent treatment
/// so users can see at a glance where to click.
///
///   - idle:     subtle 1pt secondary outline (visible in light + dark)
///   - selected: green accent fill + 1.5pt green stroke
///
/// Apply via `.clickable(isSelected:)` — it's a `.buttonStyle(.plain)` add-on.
public struct ClickableChrome: ViewModifier {
    let cornerRadius: CGFloat
    let isSelected: Bool
    let accent: Color

    public init(cornerRadius: CGFloat = 7, isSelected: Bool = false,
                accent: Color = .green) {
        self.cornerRadius = cornerRadius
        self.isSelected = isSelected
        self.accent = accent
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background { shape.fill(isSelected ? accent.opacity(0.18) : .clear) }
            .overlay {
                shape.stroke(
                    isSelected ? accent : Color.secondary.opacity(0.30),
                    lineWidth: isSelected ? 1.5 : 1
                )
            }
            .contentShape(shape)
    }
}

extension View {
    /// Standard clickable affordance — visible idle border, accented when
    /// selected. Pass `isSelected: true` for the active item in a group.
    public func clickable(isSelected: Bool = false, cornerRadius: CGFloat = 7,
                          accent: Color = .green) -> some View {
        modifier(ClickableChrome(cornerRadius: cornerRadius,
                                 isSelected: isSelected, accent: accent))
    }
}

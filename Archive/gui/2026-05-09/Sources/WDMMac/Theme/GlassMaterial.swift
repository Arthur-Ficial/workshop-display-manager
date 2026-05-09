import SwiftUI

/// Liquid Glass panel — uses macOS 26's real `View.glassEffect(_:in:)` when
/// available; on older macOS (this package's deployment target is 13)
/// falls back to the system `Material.regularMaterial`. The fallback is
/// not "fake glass" — it's the system's existing translucent material; the
/// macOS 26 path is the one we ship for the workshop GUI.
public struct GlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    public init(cornerRadius: CGFloat = 18, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if #available(macOS 26.0, *) {
                content()
                    .padding(16)
                    .glassEffect(.regular, in: shape)
            } else {
                content()
                    .padding(16)
                    .background { shape.fill(.regularMaterial) }
            }
        }
        .overlay { shape.stroke(.white.opacity(0.10), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 10)
    }
}

/// Liquid Glass `.buttonStyle(.glass)` when available; plain otherwise.
public struct LiquidGlassButtonStyle: ViewModifier {
    public func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
}

extension View {
    /// Apply Liquid Glass button style (with plain fallback on older macOS).
    public func liquidGlassButton() -> some View { modifier(LiquidGlassButtonStyle()) }
}

/// Window-level Liquid Glass surface. On macOS 26 the system promotes
/// `.containerBackground(.regularMaterial, for: .window)` to real Tahoe
/// Liquid Glass — combined with a transparent `NSWindow` (configured by
/// HeadedRunner) the chrome shows the desktop through.
public struct WindowGlassBackground: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.containerBackground(.regularMaterial, for: .window)
        } else {
            content.background(.regularMaterial)
        }
    }
}

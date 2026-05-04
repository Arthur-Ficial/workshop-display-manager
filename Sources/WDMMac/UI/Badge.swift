import SwiftUI

/// Tiny capsule badge — MAIN / ACTIVE / MIR / REC / Headless / HDR.
/// Dark-tinted background, accent foreground.
public struct Badge: View {
    let text: String
    let color: Color
    public init(_ text: String, color: Color = .green) {
        self.text = text
        self.color = color
    }
    public var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background { Capsule().fill(color.opacity(0.18)) }
    }
}

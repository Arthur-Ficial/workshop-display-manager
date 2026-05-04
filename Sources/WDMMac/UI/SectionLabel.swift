import SwiftUI

/// Small-caps tracked label used everywhere section headers appear.
/// One source for the visual treatment so MODE / IDENTITY / DISPLAYS /
/// PROFILES all read identically.
public struct SectionLabel: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}

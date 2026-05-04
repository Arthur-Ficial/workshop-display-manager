import SwiftUI

/// `[3]`-style numeric pill that follows section headers (DISPLAYS [3]).
public struct CountChip: View {
    let count: Int
    public init(count: Int) { self.count = count }
    public var body: some View {
        Text("\(count)")
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background { Capsule().fill(.secondary.opacity(0.15)) }
            .foregroundStyle(.secondary)
    }
}

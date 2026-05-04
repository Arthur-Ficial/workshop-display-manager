import SwiftUI

/// Reusable section row: SECTION_LABEL [N] (optional trailing accessory).
/// Used for sidebar sections (DISPLAYS [3], VIRTUAL [0], PROFILES [6])
/// and inspector groups.
public struct SectionHeader<Trailing: View>: View {
    let title: String
    let count: Int?
    @ViewBuilder let trailing: () -> Trailing

    public init(title: String, count: Int? = nil,
                @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.count = count
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 6) {
            SectionLabel(title)
            if let count { CountChip(count: count) }
            Spacer()
            trailing()
        }
    }
}

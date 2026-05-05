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
            if Self.showsCountChip(count) { CountChip(count: count!) }
            Spacer()
            trailing()
        }
    }

    /// Render rule for the count chip:
    /// nil → false (no count to show), 0 → false (empty-state hint
    /// already communicates the zero), >0 → true.
    public static func showsCountChip(_ count: Int?) -> Bool {
        if let count, count > 0 { return true }
        return false
    }
}

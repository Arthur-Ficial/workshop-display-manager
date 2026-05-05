import SwiftUI

/// Horizontal row of equal-width segmented buttons. Used by the GEOMETRY
/// rotation row (0/90/180/270) and the flip row (—/Flip H/Flip V).
public struct SegmentedRow<Tag: Hashable>: View {
    public struct Segment: Identifiable {
        public let id: Tag
        public let label: String
        public let remoteID: String
        public init(id: Tag, label: String, remoteID: String) {
            self.id = id; self.label = label; self.remoteID = remoteID
        }
    }
    let segments: [Segment]
    let selected: Tag?
    let onPick: (Tag) -> Void

    public init(segments: [Segment], selected: Tag?, onPick: @escaping (Tag) -> Void) {
        self.segments = segments
        self.selected = selected
        self.onPick = onPick
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(segments) { seg in
                Button { onPick(seg.id) } label: {
                    Text(seg.label).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(seg.id == selected ? .green : .primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .clickable(isSelected: seg.id == selected, cornerRadius: 6)
                .accessibilityIdentifier(seg.remoteID)
            }
        }
    }
}

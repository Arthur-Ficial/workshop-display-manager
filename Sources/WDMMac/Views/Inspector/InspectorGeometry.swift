import SwiftUI

/// GEOMETRY section — rotation row (0 / 90 / 180 / 270°) + flip row
/// (— / Flip H / Flip V). Both rows reuse the same `SegmentedRow`
/// primitive — DRY.
public struct InspectorGeometry: View {
    @State private var rotation: Int = 0
    @State private var flip: FlipMode = .none

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            SegmentedRow(
                segments: [0, 90, 180, 270].map {
                    .init(id: $0, label: "\($0)°", remoteID: "inspector.rotate.\($0)")
                },
                selected: rotation
            ) { rotation = $0 }

            SegmentedRow(
                segments: FlipMode.allCases.map {
                    .init(id: $0, label: $0.label, remoteID: "inspector.flip.\($0.rawValue)")
                },
                selected: flip
            ) { flip = $0 }
        }
        .accessibilityIdentifier("inspector.geometry")
    }
}

public enum FlipMode: String, CaseIterable, Hashable {
    case none, h, v
    var label: String {
        switch self {
        case .none: "—"
        case .h: "Flip H"
        case .v: "Flip V"
        }
    }
}

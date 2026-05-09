import SwiftUI

/// Appearance pane — single-line three-way toggle (System / Light / Dark).
/// KISS: one row, one decision, no swatches, no helper paragraph.
public struct AppearancePane: View {
    @ObservedObject var store: AppearanceStore
    public init(store: AppearanceStore) { self.store = store }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Appearance").font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: $store.mode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.shortLabel).tag(mode)
                            .accessibilityIdentifier("settings.appearance.\(mode.rawValue)")
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .labelsHidden()
                .accessibilityIdentifier("settings.appearance.picker")
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("settings.pane.appearance")
    }
}

extension AppearanceMode {
    public var shortLabel: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

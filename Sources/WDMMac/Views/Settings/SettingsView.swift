import SwiftUI

/// Tabbed Settings shell. Mirrors the macOS standard pattern: an icon
/// bar across the top selects a pane below. Each pane is its own file.
public struct SettingsView: View {
    @ObservedObject var appearance: AppearanceStore
    @State private var tab: SettingsTab = .appearance

    public init(appearance: AppearanceStore) { self.appearance = appearance }

    public var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider().opacity(0.25)
            paneFor(tab)
        }
        .frame(width: 520, height: 360)
    }

    private var tabStrip: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { t in
                Button { tab = t } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.symbol).font(.system(size: 18))
                            .foregroundStyle(t == tab ? Color.green : Color.primary)
                        Text(t.title).font(.system(size: 11, weight: .medium))
                    }
                    .frame(width: 78, height: 56)
                }
                .buttonStyle(.plain)
                .clickable(isSelected: t == tab, cornerRadius: 8)
                .accessibilityIdentifier("settings.tab.\(t.rawValue)")
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    @ViewBuilder
    private func paneFor(_ t: SettingsTab) -> some View {
        switch t {
        case .appearance: AppearancePane(store: appearance)
        case .advanced: AdvancedPane()
        case .about: AboutPane()
        }
    }
}

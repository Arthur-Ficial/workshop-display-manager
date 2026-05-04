import SwiftUI

/// Appearance settings pane — three-way picker (System / Light / Dark)
/// with a one-line explanation. Every option carries a stable remoteID
/// so the e2e harness can flip appearance via the API.
public struct AppearancePane: View {
    @ObservedObject var store: AppearanceStore
    public init(store: AppearanceStore) { self.store = store }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("APPEARANCE")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(AppearanceMode.allCases) { mode in
                    AppearanceOption(mode: mode,
                                     isSelected: store.mode == mode) {
                        store.mode = mode
                    }
                }
            }
            Text("Default follows the system Appearance setting in macOS.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("settings.pane.appearance")
    }
}

private struct AppearanceOption: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let pick: () -> Void

    var body: some View {
        Button(action: pick) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
                Text(mode.label).font(.system(size: 13, weight: .medium))
                Spacer()
                AppearanceSwatch(mode: mode)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .panel(cornerRadius: 8, opacity: isSelected ? 0.14 : 0.06)
        .accessibilityIdentifier("settings.appearance.\(mode.rawValue)")
    }
}

private struct AppearanceSwatch: View {
    let mode: AppearanceMode
    var body: some View {
        let r = RoundedRectangle(cornerRadius: 4, style: .continuous)
        switch mode {
        case .light: r.fill(.white).overlay(r.stroke(.black.opacity(0.2)))
                .frame(width: 36, height: 22)
        case .dark:  r.fill(.black).overlay(r.stroke(.white.opacity(0.2)))
                .frame(width: 36, height: 22)
        case .system:
            HStack(spacing: 0) {
                Rectangle().fill(.white)
                Rectangle().fill(.black)
            }
            .frame(width: 36, height: 22)
            .clipShape(r)
            .overlay(r.stroke(.secondary.opacity(0.3)))
        }
    }
}

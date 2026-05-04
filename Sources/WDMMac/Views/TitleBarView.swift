import SwiftUI

/// Top header per the design: app name + subtitle (surface count + current
/// profile), centered tab strip (Stage / Profiles / Recordings), and right-
/// hand pill showing the currently-applied profile.
public struct TitleBarView: View {
    @ObservedObject var vm: DisplaysListVM
    @Binding var tab: AppTab

    public init(vm: DisplaysListVM, tab: Binding<AppTab>) {
        self.vm = vm
        self._tab = tab
    }

    public var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text("wdm").font(.system(size: 13, weight: .semibold))
                Text("\(vm.tiles.count) surface\(vm.tiles.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { t in
                    Button { tab = t } label: {
                        HStack(spacing: 4) {
                            Image(systemName: t.symbol).font(.system(size: 11))
                            Text(t.title).font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(t == tab ? .white.opacity(0.10) : .clear)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("titlebar.tab.\(t.rawValue)")
                }
            }

            Spacer()

            Button {} label: {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("Default")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.white.opacity(0.06))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("titlebar.profile")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(height: 44)
        .accessibilityIdentifier("titlebar")
    }
}

public enum AppTab: String, CaseIterable, Identifiable {
    case stage, profiles, recordings
    public var id: String { rawValue }
    var title: String {
        switch self {
        case .stage: "Stage"
        case .profiles: "Profiles"
        case .recordings: "Recordings"
        }
    }
    var symbol: String {
        switch self {
        case .stage: "rectangle.3.group"
        case .profiles: "bookmark"
        case .recordings: "record.circle"
        }
    }
}

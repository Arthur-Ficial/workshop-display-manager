import SwiftUI

/// Top header per the design: app name + subtitle (surface count + current
/// profile), centered tab strip (Stage / Profiles / Recordings), and right-
/// hand pill showing the currently-applied profile.
public struct TitleBarView: View {
    @ObservedObject var vm: DisplaysListVM

    private var tab: AppTab {
        AppTab(rawValue: vm.selectedTab) ?? .stage
    }

    public init(vm: DisplaysListVM) {
        self.vm = vm
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

            HStack(spacing: 6) {
                ForEach(AppTab.allCases) { t in
                    Button { vm.selectTab(t.rawValue) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: t.symbol).font(.system(size: 11))
                            Text(t.title).font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(t == tab ? Color.green : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .clickable(isSelected: t == tab)
                    // .buttonStyle(.plain) elides the AXButton role —
                    // re-add it so the AccessibilityWalker / headed
                    // e2e tests can locate the tab as a clickable.
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("titlebar.tab.\(t.rawValue)")
                }
            }

            Spacer()

            // "Default" — applies the most-recent profile (or first
            // alphabetical) so the workshop facilitator's bookmarked
            // arrangement is one click away. Honest fallback when there
            // are no profiles: surfaces a "no profile" message via lastError.
            Button {
                if let first = vm.profiles.first {
                    vm.restoreProfile(named: first)
                } else {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text(vm.profiles.first ?? "Default")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .clickable()
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("titlebar.profile")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(height: 44)
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

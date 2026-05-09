import SwiftUI

/// The full app frame per the design briefing:
///
///     ┌────────── titlebar ──────────┐
///     │ wdm                  tabs    │
///     ├────────┬─────────────┬───────┤
///     │ side   │   stage     │ insp. │
///     │ bar    │   canvas    │       │
///     │        │             │       │
///     ├────────┴─────────────┴───────┤
///     │ statusbar (daemon · counts)  │
///     └──────────────────────────────┘
///
/// Each panel is its own .swift file ≤150 LOC. Glass treatment is supplied
/// by HeadedRunner's NSVisualEffectView (.sidebar / .behindWindow); inner
/// surfaces use subtle translucent fills so the desktop stays visible.
public struct AppFrameView: View {
    @ObservedObject var vm: DisplaysListVM
    let onSelect: (String) -> Void
    /// Active tab — bound to vm.selectedTab so headless registry
    /// `titlebar.tab.*` clicks route through `vm.selectTab(_:)`.
    private var tab: AppTab {
        AppTab(rawValue: vm.selectedTab) ?? .stage
    }

    public init(vm: DisplaysListVM, onSelect: @escaping (String) -> Void) {
        self.vm = vm
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Visible hairline at the top of the SwiftUI safe area. With
            // .fullSizeContentView the SwiftUI content extends edge-to-edge
            // but safe-area insets still account for the OS title bar — so
            // this rectangle lands exactly under the traffic lights /
            // window-title row, marking where the draggable region ends.
            Rectangle()
                .fill(Color.secondary.opacity(0.40))
                .frame(height: 1)

            TitleBarView(vm: vm)
            Divider().opacity(0.25)

            HStack(spacing: 0) {
                SidebarView(vm: vm, onSelect: onSelect)
                Divider().opacity(0.20)
                Group {
                    switch tab {
                    case .stage: StageView(vm: vm, onSelect: onSelect).padding(14)
                    case .profiles: ProfilesPaneView(vm: vm)
                    case .recordings: RecordingsPaneView(vm: vm)
                    }
                }
                Divider().opacity(0.20)
                InspectorView(vm: vm)
            }

            Divider().opacity(0.25)
            StatusBarView(vm: vm)
        }
        .frame(minWidth: 920, minHeight: 560)
        .overlay(alignment: .bottom) {
            SafeTxBannerView(vm: vm.safeTx)
        }
    }
}

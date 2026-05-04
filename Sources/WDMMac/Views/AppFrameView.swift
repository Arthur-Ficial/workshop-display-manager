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
    @State private var tab: AppTab = .stage

    public init(vm: DisplaysListVM, onSelect: @escaping (String) -> Void) {
        self.vm = vm
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            TitleBarView(vm: vm, tab: $tab)
            Divider().opacity(0.25)

            HStack(spacing: 0) {
                SidebarView(vm: vm, onSelect: onSelect)
                Divider().opacity(0.20)
                StageView(vm: vm, onSelect: onSelect)
                    .padding(14)
                Divider().opacity(0.20)
                InspectorView(vm: vm)
            }

            Divider().opacity(0.25)
            StatusBarView(vm: vm)
        }
        .frame(minWidth: 920, minHeight: 560)
        .accessibilityIdentifier("appframe")
    }
}

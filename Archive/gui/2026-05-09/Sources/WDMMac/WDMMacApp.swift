import SwiftUI

/// SwiftUI App scene. The runner builds + injects the VM and the select
/// callback. Keeping the App inert (no `@main`) lets the same WDMMac lib
/// be hosted in tests via `NSHostingView` as well as wrapped by the
/// `wdm-mac` executable.
public struct WDMMacScene: Scene {
    @ObservedObject var vm: DisplaysListVM
    let onSelect: (String) -> Void

    public init(vm: DisplaysListVM, onSelect: @escaping (String) -> Void) {
        self.vm = vm
        self.onSelect = onSelect
    }

    public var body: some Scene {
        WindowGroup("Workshop Display Manager") {
            AppFrameView(vm: vm, onSelect: onSelect)
        }
        .defaultSize(width: 1100, height: 680)
    }
}

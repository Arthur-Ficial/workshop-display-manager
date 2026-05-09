import SwiftUI

/// Center column. The Stage canvas is the **only** WebKit-rendered
/// surface in WDMMac — the rest of the app is 100% native SwiftUI.
/// We render the spatial monitor arrangement inside a `WKWebView`
/// because drag-with-snap and pinch-zoom are battle-tested in the web
/// stack and trying to match that fluidity in SwiftUI fights the
/// framework. The bridge is a tiny JSON contract.
public struct StageView: View {
    @ObservedObject var vm: DisplaysListVM
    let onSelect: (String) -> Void

    public init(vm: DisplaysListVM, onSelect: @escaping (String) -> Void) {
        self.vm = vm
        self.onSelect = onSelect
    }

    public var body: some View {
        StageWebView(state: state, onMessage: handle)
            .accessibilityIdentifier("stage.canvas")
    }

    private var state: StageState {
        StageState(
            tiles: vm.tiles.map { t in
                StageTilePayload(
                    id: t.displayID, name: t.title, isMain: t.isMain,
                    widthPx: t.widthPx, heightPx: t.heightPx,
                    originX: t.originX, originY: t.originY,
                    refreshHz: parseRefreshHz(t.subtitle),
                    wallpaperPath: t.wallpaperURL?.path
                )
            },
            selectedID: vm.selectedTile()?.displayID
        )
    }

    private func handle(_ message: StageMessage) {
        switch message {
        case .ready: break
        case .select(let id):
            onSelect("stage.tile.\(id)")
        case .dragEnd(let id, let x, let y):
            vm.commitDrag(displayID: id, originX: x, originY: y)
        case .zoom: break
        }
    }

    /// Parse "WIDTH×HEIGHT @ NHz" → N. Best-effort; refresh rate is
    /// shown inside the tile but never gates anything.
    private func parseRefreshHz(_ subtitle: String) -> Int {
        guard let at = subtitle.firstIndex(of: "@") else { return 60 }
        let suffix = subtitle[subtitle.index(after: at)...]
        let digits = suffix.filter { $0.isNumber }
        return Int(digits) ?? 60
    }
}

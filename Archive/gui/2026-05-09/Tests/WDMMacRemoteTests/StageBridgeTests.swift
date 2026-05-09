import Testing
import Foundation
@testable import WDMMac

/// Unit tests for the WebKit Stage bridge. Both directions are pure data
/// — `StageState` encodes to JSON for `window.wdm.setState(...)`, and
/// `StageMessage` decodes from `[String: Any]` posted back via
/// `WKScriptMessage.body`. These are the contract between Swift and
/// stage.js; if they drift the embedded Stage stops working.
@Suite("Stage WebKit bridge — JSON in, JSON out")
struct StageBridgeTests {
    @Test("StageState round-trips through JSON")
    func stateCodable() throws {
        let s = StageState(
            tiles: [
                StageTilePayload(id: 1, name: "Built-in", isMain: true,
                                 widthPx: 2560, heightPx: 1664,
                                 originX: 0, originY: 0, refreshHz: 60),
                StageTilePayload(id: 2, name: "Projector", isMain: false,
                                 widthPx: 3840, heightPx: 2160,
                                 originX: 2560, originY: 0, refreshHz: 60),
            ],
            selectedID: 1
        )
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(StageState.self, from: data)
        #expect(back == s)
    }

    @Test("ready message decodes")
    func readyMessage() {
        let m = StageMessage(json: ["type": "ready"])
        #expect(m == .ready)
    }

    @Test("select message decodes")
    func selectMessage() {
        let m = StageMessage(json: ["type": "select", "id": 2])
        #expect(m == .select(id: 2))
    }

    @Test("drag end message decodes")
    func dragEndMessage() {
        let m = StageMessage(json: [
            "type": "drag", "phase": "end",
            "id": 3, "originX": 1920, "originY": -540,
        ])
        #expect(m == .dragEnd(id: 3, originX: 1920, originY: -540))
    }

    @Test("drag without phase=end is rejected (in-flight moves don't bubble up)")
    func dragInFlightRejected() {
        let m = StageMessage(json: [
            "type": "drag", "phase": "move",
            "id": 1, "originX": 0, "originY": 0,
        ])
        #expect(m == nil)
    }

    @Test("zoom message decodes")
    func zoomMessage() {
        let m = StageMessage(json: ["type": "zoom", "value": 1.5])
        #expect(m == .zoom(value: 1.5))
    }

    @Test("unknown type is dropped — additive evolution, no crash")
    func unknownDropped() {
        #expect(StageMessage(json: ["type": "future"]) == nil)
        #expect(StageMessage(json: [:]) == nil)
    }
}

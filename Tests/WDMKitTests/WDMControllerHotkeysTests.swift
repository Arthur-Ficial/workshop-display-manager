import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController hotkeys daemon")
struct WDMControllerHotkeysTests {
    @Test("hotkeys daemon registers each enabled binding and dispatches fired chords")
    func runDaemon() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-hk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let log = dir.appendingPathComponent("registrar.log")
        let registrar = RecordingHotkeyRegistrar(
            logURL: log, fireChords: ["ctrl+1"]
        )
        var dispatched: [String] = []
        let outcome = try WDMController.hotkeys.runDaemon(
            bindings: [
                Keybinding(chord: "ctrl+1", command: "switch"),
                Keybinding(chord: "ctrl+2", command: "main 2"),
            ],
            registrar: registrar,
            maxEvents: 1,
            dispatch: { dispatched.append($0) }
        )
        #expect(outcome.registered == 2)
        #expect(dispatched == ["switch"])
    }

    @Test("hotkey daemon counts skipped bindings on chordTaken without throwing")
    func chordTakenSkipped() throws {
        let registrar = RejectingHotkeyRegistrar(reject: ["ctrl+1"])
        let outcome = try WDMController.hotkeys.runDaemon(
            bindings: [Keybinding(chord: "ctrl+1", command: "switch")],
            registrar: registrar,
            maxEvents: 0,
            dispatch: { _ in }
        )
        #expect(outcome.registered == 0)
        #expect(outcome.skipped == ["ctrl+1"])
    }
}

private final class RejectingHotkeyRegistrar: HotkeyRegistrar, @unchecked Sendable {
    private let reject: Set<String>
    init(reject: [String]) { self.reject = Set(reject) }
    func register(chord: String) throws {
        if reject.contains(chord) { throw HotkeyRegistrarError.chordTaken(chord) }
    }
    func run(maxEvents: Int?, onFire: @escaping (String) -> Void) {}
}

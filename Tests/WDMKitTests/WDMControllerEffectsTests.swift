import Foundation
import Testing
import WDMCore
import WDMSystem
@testable import WDMKit

@Suite("WDMController effects")
struct WDMControllerEffectsTests {
    @Test("controller routes injected effect protocols")
    func effectProtocols() throws {
        let (controller, fixture) = try makeController()
        let dir = try makeTempDirectory()
        let log = dir.appendingPathComponent("effects.log")

        try controller.screenshot("2", to: dir.appendingPathComponent("shot.png"),
                                  using: RecordingScreenshotter(logURL: log))
        try controller.record("main", to: dir.appendingPathComponent("rec.mov"), durationSec: 1,
                              using: RecordingRecorder(logURL: log))
        try controller.flipOverlay("2", flip: .vertical, durationMs: 1,
                                   using: RecordingOverlayFlipper(url: log))
        try controller.pip(source: "2", on: "main", size: .defaultSize, position: nil,
                           flip: .none, durationMs: 1, remoteControl: false,
                           using: RecordingPipFlipper(url: log))
        try controller.stream("2", target: "/tmp/hls", mode: .hls, durationSec: 1,
                              options: .default, using: RecordingStreamer(logURL: log))
        try controller.sleep(using: RecordingSleeper(url: log))

        try controller.moveWindow(pattern: "Safari", to: "2", using: RecordingWindowMover(logURL: log))
        try controller.focus("main", using: RecordingWindowMover(logURL: log))
        try controller.tileApp(pattern: "Safari", across: ["1", "2"],
                               using: RecordingWindowMover(logURL: log))
        #expect(try controller.screenWindows("2", using: RecordingWindowLister()).count == 2)

        let body = try String(contentsOf: log)
        #expect(body.contains("screenshot displayID=2"))
        #expect(body.contains("record displayID=1"))
        #expect(body.contains("run displayID=2 flip=vertical"))
        #expect(body.contains("run source=2 destination=1"))
        #expect(body.contains("stream displayID=2"))
        #expect(body.contains("sleepNow"))
        #expect(body.contains("move pattern=Safari displayID=2"))
        #expect(body.contains("focus displayID=1"))
        #expect(body.contains("tile pattern=Safari displayIDs=1,2"))

        let ddcLog = dir.appendingPathComponent("ddc.log")
        let ddc = RecordingDDCProvider(fixtureURL: fixture, logURL: ddcLog)
        #expect(try controller.ddcRead("2", vcp: DDCCodes.brightness, using: ddc) == 50)
        try controller.ddcWrite("2", vcp: DDCCodes.contrast, value: 75, using: ddc)
        #expect(try String(contentsOf: ddcLog).contains("vcp=0x12 value=75"))

        let hdrLog = dir.appendingPathComponent("hdr.log")
        let hdr = RecordingHDRProvider(fixtureURL: fixture, logURL: hdrLog)
        #expect(try controller.hdr("2", using: hdr) == false)
        try controller.setHDR("2", enabled: true, using: hdr)
        #expect(try controller.hdr("2", using: hdr) == true)
    }

    private func makeController() throws -> (WDMController, URL) {
        let fixture = try makeFixture()
        let provider = try FixtureDisplayProvider(fixtureURL: fixture)
        let profiles = try makeTempDirectory().appendingPathComponent("profiles")
        return (WDMController(provider: provider, profileStore: ProfileStore(directory: profiles), env: [:]),
                fixture)
    }

    private func makeFixture() throws -> URL {
        let url = try makeTempDirectory().appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-kit-effects-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let fixtureJSON = """
    {
      "snapshot": {
        "createdAt": 1700000000,
        "displays": [
          { "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
            "origin": { "x": 0, "y": 0 }, "rotationDegrees": 0 },
          { "id": 2, "name": "Projector", "isMain": false, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 2560, "y": 0 }, "rotationDegrees": 0 }
        ]
      },
      "availableModes": {
        "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }],
        "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
      },
      "ddc": {
        "2": { "16": 50, "18": 60 }
      },
      "hdr": {
        "2": false
      }
    }
    """
}

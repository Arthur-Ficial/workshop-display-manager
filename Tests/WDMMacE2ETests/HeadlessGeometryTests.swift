import Testing
import Foundation
@testable import WDMRemoteControl

/// Inspector GEOMETRY rotation + flip clicks must reach
/// `controller.rotate` / `controller.flip` and mutate the fixture's
/// state — proving the segments aren't no-op fakes (CLAUDE.md
/// "no fakes / no fallbacks" rule).
@Suite("wdm-mac headless: GEOMETRY rotation + flip clicks are real")
struct HeadlessGeometryTests {
    @Test func clickingRotation180RotatesFixture() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Default selection is display 1 (Built-in). Click rotation 180.
        var snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let target = snap.nodes.first { $0.remoteID == "inspector.rotate.180" }
        try #require(target != nil, "inspector.rotate.180 must exist; got \(snap.nodes.map(\.remoteID).sorted())")

        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(target!.ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        try await Task.sleep(nanoseconds: 300_000_000)

        // Fixture is the system of record.
        let bytes = try Data(contentsOf: env.fixture)
        let obj = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        let displays = (obj?["snapshot"] as? [String: Any])?["displays"] as? [[String: Any]]
        let builtIn = displays?.first { ($0["id"] as? Int) == 1 }
        let rot = builtIn?["rotationDegrees"] as? Int
        #expect(rot == 180,
                "expected rotation 180 after click; got \(String(describing: rot))")

        // Snapshot reflects the new selected segment too.
        snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let segment = snap.nodes.first { $0.remoteID == "inspector.rotate.180" }
        #expect(segment?.state.selected == true,
                "180 segment should be selected after click; state=\(String(describing: segment?.state))")
    }

    @Test func clickingFlipHFlipsFixture() async throws {
        let env = try makeEnv()
        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let target = snap.nodes.first { $0.remoteID == "inspector.flip.h" }
        try #require(target != nil, "inspector.flip.h must exist")

        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(target!.ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        try await Task.sleep(nanoseconds: 300_000_000)

        // Fixture's flip table updates.
        let bytes = try Data(contentsOf: env.fixture)
        let obj = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        let flip = obj?["flip"] as? [String: Any]
        let displayFlip = flip?["1"] as? String
        // FixtureDisplayProvider stores Flip as a stringified value;
        // exact format depends on Codable. Accept any contains-"horizontal".
        #expect(
            displayFlip?.lowercased().contains("horizontal") == true
                || (flip?["1"] as? [String: Any])?["axis"] as? String == "horizontal",
            "expected horizontal flip after click; got \(String(describing: flip))"
        )
    }
}

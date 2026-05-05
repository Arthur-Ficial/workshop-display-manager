import Testing
import Foundation
@testable import WDMRemoteControl

/// E2E for the WDMMac Inspector brightness slider. Drives every case
/// through the remote API only — no in-process shortcuts. Closes the
/// `tasks/brightness-slider-spec.md` spec.
///
/// - Read:    pre-seed fixture brightness[1] = 0.4 → snapshot exposes
///            `inspector.brightness.value` carrying 0.40.
/// - Write:   click `inspector.brightness.value.075` → fixture's
///            brightness[1] is now 0.75.
/// - Refuse:  display whose brightness is nil → `inspector.brightness.unavailable`
///            present, `inspector.brightness.slider` absent.
@Suite("wdm-mac headless: Inspector brightness slider")
struct HeadlessBrightnessTests {
    @Test func readShowsCurrentValue() async throws {
        let env = try makeEnv()
        try seedBrightness(table: ["1": 0.4, "2": nil], in: env)

        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let valueNode = snap.nodes.first { $0.remoteID == "inspector.brightness.value" }
        try #require(valueNode != nil, "inspector.brightness.value must surface for the selected (Built-in) display")
        #expect(valueNode?.value?.contains("0.4") == true,
                "expected the value to render 0.40; got \(String(describing: valueNode?.value))")
    }

    @Test func clickingPresetWritesBrightness() async throws {
        let env = try makeEnv()
        try seedBrightness(table: ["1": 0.4, "2": nil], in: env)

        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        var snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let preset = snap.nodes.first { $0.remoteID == "inspector.brightness.value.075" }
        try #require(preset != nil, "0.75 preset button must be registered for supported displays")

        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(preset!.ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
        try await Task.sleep(nanoseconds: 300_000_000)

        // Fixture file is authoritative. The brightness write persisted
        // via FixtureDisplayProvider.persist().
        let bytes = try Data(contentsOf: env.fixture)
        let obj = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        let brightness = obj?["brightness"] as? [String: Any]
        let actual = brightness?["1"] as? Double
        #expect(actual == 0.75,
                "expected fixture brightness[\"1\"] == 0.75; got \(String(describing: actual))")

        // Re-snapshot — value reflects new state.
        snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let updated = snap.nodes.first { $0.remoteID == "inspector.brightness.value" }
        #expect(updated?.value?.contains("0.75") == true,
                "expected reload to show 0.75; got \(String(describing: updated?.value))")
    }

    @Test func unsupportedShowsUnavailableHint() async throws {
        let env = try makeEnv()
        // Display 1 (the default selection) has no brightness entry.
        try seedBrightness(table: ["1": nil, "2": 0.4], in: env)

        let proc = try spawnHeadless(env: env)
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let ids = Set(snap.nodes.map(\.remoteID))
        #expect(ids.contains("inspector.brightness.unavailable"),
                "expected refusal hint; got \(ids.sorted())")
        #expect(!ids.contains("inspector.brightness.slider"),
                "slider must NOT appear when brightness is unsupported")
        #expect(!ids.contains("inspector.brightness.value.075"),
                "preset clicks must NOT appear when brightness is unsupported")
    }

    /// Mutates the fixture file in place to add the `brightness` key
    /// expected by FixtureDisplayProvider. Each entry maps display ID
    /// to optional Float — nil means "this display has no brightness
    /// control" (per FixtureFile docs).
    private func seedBrightness(table: [String: Float?], in env: E2EEnv) throws {
        let bytes = try Data(contentsOf: env.fixture)
        guard var obj = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
            return
        }
        var encoded: [String: Any] = [:]
        for (id, value) in table {
            encoded[id] = value.map { Double($0) } ?? NSNull()
        }
        obj["brightness"] = encoded
        let out = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted])
        try out.write(to: env.fixture, options: .atomic)
    }
}

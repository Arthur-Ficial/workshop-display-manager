import Testing
import Foundation
@testable import WDMRemoteControl

/// Drives the Inspector's "Change Background" action through the full
/// remote-API flow. With WDM_TEST_WALLPAPER_PATH set, the registry's
/// click handler substitutes for NSOpenPanel and feeds the URL to
/// `controller.setWallpaper`. Asserts:
///   1. POST /ui/click on inspector.action.change-background → ok:true
///   2. The on-disk wallpaper fixture mutates to the test URL
///   3. The SafeTx banner appears in /ui/snapshot during the change
@Suite("wdm-mac headless: Change Background flow", .serialized)
struct HeadlessChangeBackgroundTests {
    @Test func clickingChangeBackgroundAppliesToFixture() async throws {
        let env = try makeEnv()
        let testWallpaperFixture = env.dir.appendingPathComponent("wallpapers.json")
        try #"{"1":"/tmp/old.jpg"}"#
            .write(to: testWallpaperFixture, atomically: true, encoding: .utf8)
        let testNewURL = "/tmp/changed.jpg"

        let proc = try spawnHeadless(env: env, extraEnv: [
            "WDM_TEST_WALLPAPER": testWallpaperFixture.path,
            "WDM_TEST_WALLPAPER_PATH": testNewURL
        ])
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        // Click Change Background — fires changeBackground via the env-injected URL.
        try await postClick(port: port, ref: try findRef(port: port, id: "inspector.action.change-background"))

        // Banner should appear (Kit op routes through SafeTxVM).
        let keepRef = try await waitForRef(port: port, id: "safetx.banner.keep", timeoutMs: 1500)
        try await postClick(port: port, ref: keepRef)

        // Wait for the registry restamp + on-disk write to settle.
        try await Task.sleep(nanoseconds: 300_000_000)

        // Assert the fixture mutated.
        let bytes = try Data(contentsOf: testWallpaperFixture)
        let dict = (try JSONSerialization.jsonObject(with: bytes) as? [String: String]) ?? [:]
        #expect(dict["1"] == testNewURL,
                "expected wallpaper fixture to update to \(testNewURL); got \(dict)")
    }

    // MARK: - helpers (mirror HeadlessSafeTxTests; kept inline here because
    // the harness's spawnHeadless doesn't take extraEnv — see Harness.swift).

    private func findRef(port: UInt16, id: String) async throws -> Ref {
        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let node = snap.nodes.first { $0.remoteID == id }
        try #require(node != nil, "\(id) must exist; got \(snap.nodes.map(\.remoteID).sorted())")
        return node!.ref
    }

    private func waitForRef(port: UInt16, id: String, timeoutMs: Int) async throws -> Ref {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            let snap = try SceneTreeJSON.decode(
                try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
            )
            if let node = snap.nodes.first(where: { $0.remoteID == id }) {
                return node.ref
            }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        Issue.record("remoteID \(id) never appeared within \(timeoutMs)ms")
        throw CancellationError()
    }

    private func postClick(port: UInt16, ref: Ref) async throws {
        var click = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ui/click")!)
        click.httpMethod = "POST"
        click.httpBody = Data(#"{"ref":"\#(ref.rawValue)"}"#.utf8)
        let (_, resp) = try await URLSession.shared.data(for: click)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)
    }
}

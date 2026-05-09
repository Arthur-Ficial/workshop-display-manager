import Testing
import Foundation
@testable import WDMRemoteControl

/// Asserts that `displays.tile.<id>.wallpaper` is exposed in
/// `/ui/snapshot` when a wallpaper URL is known for the display.
/// Powers tile preview rendering (SidebarDisplayRow thumbnail,
/// Stage tile background) — the lib-level read flowing all the way
/// out to AI / test consumers via the registry.
@Suite("wdm-mac headless: tile wallpaper URL exposed in /ui/snapshot",
       .serialized)
struct HeadlessWallpaperPreviewTests {
    @Test func wallpaperNodePresentForKnownDisplay() async throws {
        let env = try makeEnv()
        let testFixture = env.dir.appendingPathComponent("wallpapers.json")
        try #"{"1":"/tmp/builtin.jpg","2":"/tmp/projector.jpg"}"#
            .write(to: testFixture, atomically: true, encoding: .utf8)

        let proc = try spawnHeadless(env: env, extraEnv: [
            "WDM_TEST_WALLPAPER": testFixture.path
        ])
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let one = snap.nodes.first { $0.remoteID == "displays.wallpaper.1" }
        let two = snap.nodes.first { $0.remoteID == "displays.wallpaper.2" }
        #expect(one?.value == "/tmp/builtin.jpg",
                "expected display 1 wallpaper /tmp/builtin.jpg; got \(String(describing: one?.value))")
        #expect(two?.value == "/tmp/projector.jpg",
                "expected display 2 wallpaper /tmp/projector.jpg; got \(String(describing: two?.value))")
    }

    @Test func wallpaperNodeOmittedForUnknownDisplay() async throws {
        let env = try makeEnv()
        let testFixture = env.dir.appendingPathComponent("wallpapers.json")
        try #"{"1":"/tmp/only-1.jpg"}"#
            .write(to: testFixture, atomically: true, encoding: .utf8)

        let proc = try spawnHeadless(env: env, extraEnv: [
            "WDM_TEST_WALLPAPER": testFixture.path
        ])
        defer { proc.terminate() }
        let port = try waitForPort(stateFile: env.stateFile)

        let snap = try SceneTreeJSON.decode(
            try await get(URL(string: "http://127.0.0.1:\(port)/ui/snapshot")!)
        )
        let two = snap.nodes.first { $0.remoteID == "displays.wallpaper.2" }
        #expect(two == nil, "display 2 has no wallpaper; expected no wallpaper node, got \(String(describing: two))")
    }
}

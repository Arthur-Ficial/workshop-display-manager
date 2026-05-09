import Testing
import Foundation
@testable import WDMSystem

@Suite("WallpaperProvider — recording impl + factory")
struct WallpaperProviderTests {
    @Test("RecordingWallpaperProvider returns mapped URL by displayID")
    func mappedReturns() {
        let url = URL(fileURLWithPath: "/tmp/wp.jpg")
        let prov = RecordingWallpaperProvider(mappings: [1: url])
        #expect(prov.wallpaper(for: 1) == url)
    }

    @Test("RecordingWallpaperProvider returns nil for unmapped displayID")
    func unmappedReturnsNil() {
        let prov = RecordingWallpaperProvider(mappings: [1: URL(fileURLWithPath: "/tmp/x")])
        #expect(prov.wallpaper(for: 99) == nil)
    }

    @Test("RecordingWallpaperProvider parses fixture JSON file")
    func fixtureRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-wp-test-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("fixture.json")
        let json = #"{"1":"/tmp/builtin.jpg","2":"/tmp/projector.jpg"}"#
        try json.write(to: path, atomically: true, encoding: .utf8)

        let prov = try RecordingWallpaperProvider(fixtureURL: path)
        #expect(prov.wallpaper(for: 1)?.path == "/tmp/builtin.jpg")
        #expect(prov.wallpaper(for: 2)?.path == "/tmp/projector.jpg")
        #expect(prov.wallpaper(for: 3) == nil)
    }

    @Test("WallpaperProviderFactory uses recording impl when WDM_TEST_WALLPAPER is set")
    func factoryUsesRecordingWhenEnvSet() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-wp-test-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("fixture.json")
        try #"{"1":"/tmp/x.jpg"}"#.write(to: path, atomically: true, encoding: .utf8)

        let prov = WallpaperProviderFactory.make(env: ["WDM_TEST_WALLPAPER": path.path])
        #expect(prov.wallpaper(for: 1)?.path == "/tmp/x.jpg")
        #expect(prov.wallpaper(for: 2) == nil)
    }

    @Test("WallpaperProviderFactory falls back to recording-empty on bad fixture path")
    func factoryFallsBackOnBadPath() {
        let prov = WallpaperProviderFactory.make(env: ["WDM_TEST_WALLPAPER": "/no/such/file.json"])
        #expect(prov.wallpaper(for: 1) == nil)
    }
}

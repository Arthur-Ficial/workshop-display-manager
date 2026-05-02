import Testing
import Foundation
@testable import WDMCore

@Suite("Scene")
struct SceneTests {

    @Test("a scene is a list of SceneEntry value types")
    func sceneShape() {
        let entry = SceneEntry(
            spec: VirtualDisplaySpec.defaultSpec(name: "audience"),
            wallpaper: "/System/Library/Desktop Pictures/iMac Green.heic",
            mirrorOn: 1
        )
        #expect(entry.spec.name == "audience")
        #expect(entry.wallpaper == "/System/Library/Desktop Pictures/iMac Green.heic")
        #expect(entry.mirrorOn == 1)
    }

    @Test("Codable round-trips with optional wallpaper / mirrorOn")
    func codable() throws {
        let entries: [SceneEntry] = [
            SceneEntry(spec: VirtualDisplaySpec.defaultSpec(name: "a"), wallpaper: nil, mirrorOn: nil),
            SceneEntry(
                spec: VirtualDisplaySpec(
                    name: "b", width: 1280, height: 720, refreshHz: 60,
                    hiDPI: true, widthMM: 600, heightMM: 340
                ),
                wallpaper: "/x/y.heic",
                mirrorOn: 2
            ),
        ]
        let data = try JSONEncoder().encode(entries)
        let decoded = try JSONDecoder().decode([SceneEntry].self, from: data)
        #expect(decoded == entries)
    }

    @Test("SceneEntry decodes from JSON without optional keys")
    func decodeMinimal() throws {
        let json = """
        [{"spec": {"name": "x", "width": 800, "height": 600, "refreshHz": 60,
                   "hiDPI": true, "widthMM": 500, "heightMM": 300}}]
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode([SceneEntry].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].spec.name == "x")
        #expect(decoded[0].wallpaper == nil)
        #expect(decoded[0].mirrorOn == nil)
    }
}

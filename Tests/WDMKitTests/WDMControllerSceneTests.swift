import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController scene")
struct WDMControllerSceneTests {
    @Test("scene plan loads entries from the SceneStore")
    func loadsScene() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-scene-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = SceneStore(directory: dir.appendingPathComponent("scenes"))
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let json = """
        [
          {"spec": {"name":"a","width":1920,"height":1080,"refreshHz":60,"hiDPI":true,"widthMM":600,"heightMM":340}},
          {"spec": {"name":"b","width":1366,"height":768,"refreshHz":60,"hiDPI":false,"widthMM":600,"heightMM":340},
           "wallpaper": "/tmp/wp.png", "mirrorOn": 1}
        ]
        """
        try json.write(to: store.directory.appendingPathComponent("ws.json"), atomically: true, encoding: .utf8)

        let entries = try WDMController.scene.load(name: "ws", store: store)
        #expect(entries.count == 2)
        #expect(entries[1].mirrorOn == 1)
    }

    @Test("scene throws sceneNotFound when the file is missing")
    func notFound() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-scene-nf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = SceneStore(directory: dir.appendingPathComponent("scenes"))
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        #expect(throws: WDMError.sceneNotFound("missing").self) {
            _ = try WDMController.scene.load(name: "missing", store: store)
        }
    }
}

import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController virtual")
struct WDMControllerVirtualTests {
    @Test("presets returns the catalog")
    func presets() {
        let p = WDMController.virtual.presets()
        #expect(!p.isEmpty)
    }

    @Test("save snapshots running wdm virtual create commands as specs")
    func saveCapturesRunningSpecs() throws {
        let dir = makeDir()
        let store = VirtualSceneStore(directory: dir.appendingPathComponent("scenes"))
        let lister = RecordingProcessLister(entries: [
            (pid: 1234, command: "/usr/local/bin/wdm virtual create --name ipad --mode 1366x1024@60 --hidpi"),
            (pid: 5678, command: "/usr/local/bin/wdm virtual create --name iphone --mode 1170x2532@60"),
            (pid: 9999, command: "unrelated process"),
        ])
        let saved = try WDMController.virtual.save(name: "scene-a", store: store, lister: lister)
        #expect(saved.count == 2)
        #expect(saved.map(\.name).sorted() == ["ipad", "iphone"])
        #expect(try store.load(name: "scene-a").count == 2)
    }

    @Test("remove SIGTERMs every matching process and throws virtualNotFound on no match")
    func removeMatching() throws {
        let lister = RecordingProcessLister(entries: [
            (pid: 1, command: "wdm virtual create --name a"),
            (pid: 2, command: "wdm virtual create --name b"),
        ])
        let signaler = RecordingProcessSignaler()

        let killed = try WDMController.virtual.remove(target: "a", lister: lister, signaler: signaler)
        #expect(killed == [1])
        #expect(signaler.terminated() == [1])

        #expect(throws: WDMError.virtualNotFound("zzz").self) {
            _ = try WDMController.virtual.remove(target: "zzz", lister: lister, signaler: signaler)
        }
    }

    @Test("parseSpec round-trips a typical command line")
    func parseSpec() throws {
        let s = WDMController.virtual.parseSpec(
            from: "/usr/local/bin/wdm virtual create --name galaxy --mode 1080x2340@60 --hidpi"
        )
        #expect(s?.name == "galaxy")
        #expect(s?.width == 1080)
        #expect(s?.height == 2340)
        #expect(s?.hiDPI == true)
    }

    private func makeDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-virtual-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

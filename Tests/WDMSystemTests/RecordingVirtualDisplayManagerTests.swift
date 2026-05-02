import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

@Suite("RecordingVirtualDisplayManager")
struct RecordingVirtualDisplayManagerTests {

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-vd-rec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vd.log")
    }

    @Test("run with --duration-ms writes a single line and returns")
    func runWithDuration() throws {
        let url = try makeLogFile()
        let mgr = RecordingVirtualDisplayManager(url: url)
        let spec = VirtualDisplaySpec.defaultSpec(name: "Demo")
        try mgr.run(spec: spec, durationMs: 50)
        let body = try String(contentsOf: url)
        let line = body.split(separator: "\n").map(String.init).first ?? ""
        #expect(line.hasPrefix("run "))
        #expect(line.contains("name=Demo"))
        #expect(line.contains("1920x1080@60"))
        #expect(line.contains("hiDPI=true"))
        #expect(line.contains("durationMs=50"))
    }

    @Test("run without duration blocks until stop() is called")
    func runBlocksUntilStop() async throws {
        let url = try makeLogFile()
        let mgr = RecordingVirtualDisplayManager(url: url)
        let spec = VirtualDisplaySpec.defaultSpec(name: "Block")

        let started = Date()
        let task = Task.detached {
            try mgr.run(spec: spec, durationMs: nil)
        }
        try await Task.sleep(nanoseconds: 80_000_000)  // 80ms
        mgr.stop()
        _ = try await task.value
        let elapsed = Date().timeIntervalSince(started)
        #expect(elapsed >= 0.08)
        #expect(elapsed < 1.0)  // stop arrived; we exited quickly

        let body = try String(contentsOf: url)
        #expect(body.contains("run "))
        #expect(body.contains("durationMs=nil"))
        #expect(body.contains("stop"))
    }
}

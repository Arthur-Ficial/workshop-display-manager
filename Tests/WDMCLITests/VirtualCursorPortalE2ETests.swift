import Foundation
import Testing
@testable import WDMCLI

@Suite("wdm virtual cursor portal (e2e, recording manager)")
struct VirtualCursorPortalE2ETests {

    @Test("virtual create starts the edge cursor portal")
    func createStartsCursorPortal() throws {
        let fixture = try CLITestHarness.makeFixture()
        let log = try makeLogFile()
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let code = CLIRunner.run(
            args: [
                "virtual", "create", "--name", "Phone",
                "--preset", "iphone-17-pro-max",
                "--duration-ms", "50",
            ],
            env: [
                "WDM_TEST_FIXTURE": fixture.path,
                "WDM_TEST_VIRTUAL_LOG": log.path,
            ],
            stdout: stdout,
            stderr: stderr
        )

        #expect(code == 0)
        let body = try String(contentsOf: log)
        #expect(body.contains("cursorPortal=edge-event-tap"))
    }

    private func makeLogFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-virtual-cursor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("virtual.log")
    }
}

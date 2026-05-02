import Testing
import Foundation
@testable import WDMCore
@testable import WDMCLI

@Suite("wdm watch (e2e)")
struct WatchCommandE2ETests {

    private func makeEventsFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("events.jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return url
    }

    private func run(args: [String], fixture: URL, events: URL) -> CLIResult {
        let stdout = BufferOutputWriter()
        let stderr = BufferOutputWriter()
        let env: [String: String] = [
            "WDM_TEST_FIXTURE": fixture.path,
            "WDM_TEST_EVENTS_FILE": events.path,
        ]
        let code = CLIRunner.run(args: args, env: env, stdout: stdout, stderr: stderr)
        return CLIResult(exitCode: code, stdout: stdout.contents, stderr: stderr.contents)
    }

    @Test("--json --max-events 2 streams two events then exits 0")
    func twoEvents() async throws {
        let fx = try CLITestHarness.makeFixture()
        let evts = try makeEventsFile()

        let producer = Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            let h = try FileHandle(forWritingTo: evts)
            defer { try? h.close() }
            try h.seekToEnd()
            let e1 = DisplayEvent(timestamp: Date(timeIntervalSince1970: 1), kind: .added, displayID: 7)
            let e2 = DisplayEvent(timestamp: Date(timeIntervalSince1970: 2), kind: .removed, displayID: 7)
            try h.write(contentsOf: try JSONEncoder().encode(e1))
            try h.write(contentsOf: Data("\n".utf8))
            try h.write(contentsOf: try JSONEncoder().encode(e2))
            try h.write(contentsOf: Data("\n".utf8))
        }

        let result = run(args: ["watch", "--json", "--max-events", "2"], fixture: fx, events: evts)
        _ = await producer.result

        #expect(result.exitCode == 0)
        let lines = result.stdout
            .split(separator: "\n").map { String($0) }
            .filter { !$0.isEmpty }
        #expect(lines.count == 2)

        let parsed = try lines.map { try JSONDecoder().decode(DisplayEvent.self, from: Data($0.utf8)) }
        #expect(parsed[0].kind == .added)
        #expect(parsed[0].displayID == 7)
        #expect(parsed[1].kind == .removed)
    }

    @Test("default human format prints one line per event")
    func humanFormat() async throws {
        let fx = try CLITestHarness.makeFixture()
        let evts = try makeEventsFile()

        let producer = Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            let h = try FileHandle(forWritingTo: evts)
            defer { try? h.close() }
            try h.seekToEnd()
            let e = DisplayEvent(timestamp: Date(), kind: .modeChanged, displayID: 3)
            try h.write(contentsOf: try JSONEncoder().encode(e))
            try h.write(contentsOf: Data("\n".utf8))
        }

        let result = run(args: ["watch", "--max-events", "1"], fixture: fx, events: evts)
        _ = await producer.result

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("modeChanged"))
        #expect(result.stdout.contains("3"))
    }
}

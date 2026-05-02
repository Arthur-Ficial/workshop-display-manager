import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

@Suite("DisplayEvent + EventStream (pure)")
struct EventStreamTests {

    @Test("DisplayEvent encodes to JSON with kind + displayId + timestamp")
    func eventJSON() throws {
        let event = DisplayEvent(
            timestamp: Date(timeIntervalSince1970: 1700000000),
            kind: .added,
            displayID: 42
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(DisplayEvent.self, from: data)
        #expect(decoded == event)
    }

    @Test("DisplayEvent kind covers add / remove / mode / move / mirror / mainChanged")
    func kinds() {
        // Compile-time check: enum exhaustiveness.
        let all: [DisplayEvent.Kind] = [
            .added, .removed, .modeChanged, .moved, .mirrorChanged, .mainChanged
        ]
        #expect(all.count == 6)
    }

    @Test("EventStreamFile reader yields events written to a JSONL file")
    func fileBackedStream() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-evt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("events.jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil)

        // Producer writes two events, then a sentinel, in the background.
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            let e1 = DisplayEvent(timestamp: Date(), kind: .added, displayID: 1)
            let e2 = DisplayEvent(timestamp: Date(), kind: .removed, displayID: 2)
            try handle.write(contentsOf: try JSONEncoder().encode(e1))
            try handle.write(contentsOf: Data("\n".utf8))
            try handle.write(contentsOf: try JSONEncoder().encode(e2))
            try handle.write(contentsOf: Data("\n".utf8))
        }

        var collected: [DisplayEvent] = []
        let reader = EventStreamFile(url: url, pollIntervalMs: 25)
        for try await event in reader.events.prefix(2) {
            collected.append(event)
        }

        #expect(collected.count == 2)
        #expect(collected[0].kind == .added)
        #expect(collected[0].displayID == 1)
        #expect(collected[1].kind == .removed)
        #expect(collected[1].displayID == 2)
    }

    @Test("EventStreamFile fails the stream on a malformed JSONL line — no silent fallback")
    func malformedLineFailsStream() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-evt-bad-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("events.jsonl")
        try Data("not-valid-json\n".utf8).write(to: url)

        let reader = EventStreamFile(url: url, pollIntervalMs: 25)
        var threw = false
        do {
            for try await _ in reader.events { /* should not yield */ }
        } catch let error as ProviderError {
            if case .ioError(let msg) = error, msg.contains("malformed line") { threw = true }
        }
        #expect(threw, "EventStreamFile must surface malformed JSONL as a stream error")
    }
}

import Foundation
import Testing
import WDMSystem
@testable import WDMKit

@Suite("WDMController watch")
struct WDMControllerWatchTests {
    @Test("watch yields events from the supplied stream up to max")
    func boundedWatch() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let log = dir.appendingPathComponent("events.jsonl")
        let event = DisplayEvent(timestamp: Date(timeIntervalSince1970: 100), kind: .added, displayID: 1)
        let line = try JSONEncoder().encode(event)
        try (String(decoding: line, as: UTF8.self) + "\n").data(using: .utf8)!.write(to: log)

        let stream = EventStreamFile(url: log)
        var received: [DisplayEvent] = []
        try await WDMController.watch(stream: stream, max: 1) { event in
            received.append(event)
        }
        #expect(received.count == 1)
        #expect(received.first?.displayID == 1)
    }
}

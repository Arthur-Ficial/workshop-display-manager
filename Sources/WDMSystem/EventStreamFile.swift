import Foundation
import WDMCore

/// File-backed event stream for hermetic tests and the fixture provider:
/// reads JSONL (one DisplayEvent per line) from `url`, polling for new lines
/// every `pollIntervalMs` milliseconds. Yields events as an AsyncThrowingStream
/// so the consumer can `for try await` them.
public struct EventStreamFile: Sendable {
    public let url: URL
    public let pollIntervalMs: Int

    public init(url: URL, pollIntervalMs: Int = 100) {
        self.url = url
        self.pollIntervalMs = pollIntervalMs
    }

    public var events: AsyncThrowingStream<DisplayEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let decoder = JSONDecoder()
                var offset: UInt64 = 0
                var carry = ""
                while !Task.isCancelled {
                    let handle: FileHandle
                    do {
                        handle = try FileHandle(forReadingFrom: self.url)
                    } catch {
                        try await Task.sleep(nanoseconds: UInt64(self.pollIntervalMs) * 1_000_000)
                        continue
                    }
                    defer { try? handle.close() }
                    try handle.seek(toOffset: offset)
                    let chunk = try handle.readToEnd() ?? Data()
                    offset += UInt64(chunk.count)
                    if !chunk.isEmpty, let s = String(data: chunk, encoding: .utf8) {
                        carry += s
                        while let nl = carry.firstIndex(of: "\n") {
                            let line = String(carry[..<nl])
                            carry = String(carry[carry.index(after: nl)...])
                            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                            do {
                                let event = try decoder.decode(DisplayEvent.self, from: Data(line.utf8))
                                continuation.yield(event)
                            } catch {
                                // Bad line — skip rather than fail the stream.
                            }
                        }
                    }
                    try await Task.sleep(nanoseconds: UInt64(self.pollIntervalMs) * 1_000_000)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

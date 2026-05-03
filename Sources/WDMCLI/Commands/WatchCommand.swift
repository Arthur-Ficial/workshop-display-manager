import Foundation
import WDMKit

public enum WatchCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        let useJSON = args.contains("--json")
        let max = parseMaxEvents(args)
        let semaphore = DispatchSemaphore(value: 0)

        let task = Task {
            do {
                try await WDMController.watch(stream: deps.eventStream, max: max) { event in
                    if useJSON {
                        let data = try JSONEncoder().encode(event)
                        if let line = String(data: data, encoding: .utf8) {
                            deps.stdout.writeLine(line)
                        }
                    } else {
                        deps.stdout.writeLine(
                            "\(event.timestamp)  \(event.kind.rawValue)  display=\(event.displayID)"
                        )
                    }
                }
            } catch {
                deps.stderr.writeLine("error: \(error)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        _ = task
        return ExitCodes.success
    }

    private static func parseMaxEvents(_ args: [String]) -> Int? {
        guard let idx = args.firstIndex(of: "--max-events"),
              args.count > idx + 1,
              let n = Int(args[idx + 1]) else { return nil }
        return n
    }
}

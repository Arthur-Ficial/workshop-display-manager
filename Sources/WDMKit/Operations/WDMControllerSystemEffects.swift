import Foundation
import WDMSystem

extension WDMController {
    public func sleep(using sleeper: Sleeper) throws {
        try mapErrors {
            try sleeper.sleepNow()
        }
    }

    public func disconnectDisplay(
        _ alias: String,
        durationMs: Int,
        using capturer: DisplayCapturer
    ) throws {
        try mapErrors {
            let id = try get(alias).id
            try capturer.capture(id)
            defer { try? capturer.release(id) }
            Thread.sleep(forTimeInterval: TimeInterval(durationMs) / 1000.0)
        }
    }
}

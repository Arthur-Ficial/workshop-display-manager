import Foundation
import WDMSystem

extension WDMController {
    public struct FollowPlan: Equatable, Sendable {
        public let destinationAlias: String
        public let pollMs: Int
        public let durationMs: Int?

        public init(destinationAlias: String, pollMs: Int = 500, durationMs: Int? = nil) {
            self.destinationAlias = destinationAlias
            self.pollMs = pollMs
            self.durationMs = durationMs
        }
    }

    /// Re-target a PIP whenever the cursor enters a different display. The
    /// loop exits when:
    /// 1. `cursor.currentDisplayID()` returns nil (mocks signal end-of-stream),
    /// 2. `durationMs` elapses, or
    /// 3. `shouldStop` returns true.
    public func follow(
        plan: FollowPlan,
        cursor: CursorTracker,
        pip: PipFlipper,
        shouldStop: () -> Bool = { false }
    ) throws {
        try mapErrors {
            let destinationID = try resolve(plan.destinationAlias)
            let deadline: Date? = plan.durationMs.map {
                Date(timeIntervalSinceNow: TimeInterval($0) / 1000.0)
            }
            var lastSrc: UInt32 = 0
            while !shouldStop() {
                guard let src = cursor.currentDisplayID() else { return }
                if src != lastSrc, src != destinationID {
                    do {
                        try pip.run(
                            sourceID: src, destinationID: destinationID,
                            size: PipSize.defaultSize, position: nil,
                            flip: .none, durationMs: plan.pollMs,
                            remoteControl: false
                        )
                    } catch let error as WDMError {
                        throw error
                    } catch {
                        throw WDMError.ioError("follow: PIP failed: \(error)")
                    }
                    lastSrc = src
                } else {
                    Thread.sleep(forTimeInterval: TimeInterval(plan.pollMs) / 1000.0)
                }
                if let d = deadline, Date() >= d { return }
            }
        }
    }
}

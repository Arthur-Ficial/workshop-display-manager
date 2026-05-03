import Foundation
import WDMSystem

extension WDMController {
    public struct DoctorReport: Equatable, Sendable, Codable {
        public let displayID: UInt32
        public let name: String?
        public let isMain: Bool
        public let isOnline: Bool
        public let mirrorSource: UInt32?
        public let mode: Mode
        public let origin: Point
        public let rotationDegrees: Int

        public init(_ display: DisplayInfo) {
            self.displayID = display.id
            self.name = display.name
            self.isMain = display.isMain
            self.isOnline = display.isOnline
            self.mirrorSource = display.mirrorSource
            self.mode = display.currentMode
            self.origin = display.origin
            self.rotationDegrees = display.rotationDegrees
        }

        enum CodingKeys: String, CodingKey {
            case displayID = "id"
            case name, isMain, isOnline, mirrorSource, mode, origin, rotationDegrees
        }
    }

    public struct DoctorDisconnectPlan: Equatable, Sendable {
        public let alias: String
        public let durationMs: Int?
        public init(alias: String, durationMs: Int?) {
            self.alias = alias
            self.durationMs = durationMs
        }
    }

    /// Inspect each display: same fields as `wdm probe`. Pass `nil` for all displays.
    public func doctorProbe(alias: String?) throws -> [DoctorReport] {
        try mapErrors {
            let snap = try provider.snapshot()
            if let alias {
                let id = try DisplayResolver.resolve(alias, in: snap)
                guard let d = snap.display(id: id) else {
                    throw WDMError.displayNotFound(id)
                }
                return [DoctorReport(d)]
            }
            return snap.displays.map(DoctorReport.init)
        }
    }

    /// Capture a display (soft-disconnect) for `durationMs` (or until `shouldStop`).
    public func doctorDisconnect(
        plan: DoctorDisconnectPlan,
        using capturer: DisplayCapturer,
        shouldStop: () -> Bool = { false }
    ) throws {
        try mapErrors {
            let id = try resolve(plan.alias)
            do {
                try capturer.capture(id)
            } catch {
                throw WDMError.displayCaptureFailed(id)
            }
            defer { try? capturer.release(id) }
            if let ms = plan.durationMs {
                let deadline = Date(timeIntervalSinceNow: TimeInterval(ms) / 1000.0)
                while Date() < deadline && !shouldStop() {
                    Thread.sleep(forTimeInterval: 0.01)
                }
            } else {
                while !shouldStop() {
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
        }
    }
}

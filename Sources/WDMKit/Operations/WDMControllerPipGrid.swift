import Foundation
import WDMSystem

extension WDMController {
    public struct PipGridPlan: Equatable, Sendable {
        public let sourceAliases: [String]
        public let destinationAlias: String
        public let cols: Int?
        public let durationMs: Int?
        public let margin: Int

        public init(
            sourceAliases: [String],
            destinationAlias: String,
            cols: Int?,
            durationMs: Int?,
            margin: Int = 8
        ) {
            self.sourceAliases = sourceAliases
            self.destinationAlias = destinationAlias
            self.cols = cols
            self.durationMs = durationMs
            self.margin = margin
        }
    }

    public struct PipPlacement: Equatable, Sendable {
        public let sourceID: UInt32
        public let destinationID: UInt32
        public let size: PipSize
        public let position: PipPosition?
        public let durationMs: Int?
    }

    public func pipGridLayout(plan: PipGridPlan) throws -> [PipPlacement] {
        try mapErrors {
            let snap = try provider.snapshot()
            let sources = try plan.sourceAliases.map {
                try DisplayResolver.resolve($0, in: snap)
            }
            let destination = try DisplayResolver.resolve(plan.destinationAlias, in: snap)
            guard let dstInfo = snap.display(id: destination) else {
                throw WDMError.displayNotFound(destination)
            }
            return Self.layout(sources: sources, destination: destination,
                               displayWidth: dstInfo.currentMode.width,
                               displayHeight: dstInfo.currentMode.height,
                               cols: plan.cols, margin: plan.margin,
                               durationMs: plan.durationMs)
        }
    }

    public func pipGrid(plan: PipGridPlan, using flipper: PipFlipper) throws {
        let placements = try pipGridLayout(plan: plan)
        let errorBox = PipGridErrorBox()
        let group = DispatchGroup()
        for placement in placements {
            group.enter()
            Task.detached(priority: .userInitiated) {
                defer { group.leave() }
                do {
                    try flipper.run(
                        sourceID: placement.sourceID,
                        destinationID: placement.destinationID,
                        size: placement.size, position: placement.position,
                        flip: .none, durationMs: placement.durationMs,
                        remoteControl: false
                    )
                } catch {
                    errorBox.set(error)
                }
            }
        }
        group.wait()
        if let error = errorBox.get() { throw Self.mapPipError(error) }
    }

    static func mapPipError(_ error: Error) -> WDMError {
        if let error = error as? WDMError { return error }
        return .ioError("pip-grid: PIP failed: \(error)")
    }

    static func layout(
        sources: [UInt32], destination: UInt32,
        displayWidth dw: Int, displayHeight dh: Int,
        cols specifiedCols: Int?, margin m: Int,
        durationMs: Int?
    ) -> [PipPlacement] {
        let cols = specifiedCols
            ?? max(1, Int(Double(sources.count).squareRoot().rounded(.up)))
        let rows = max(1, Int((Double(sources.count) / Double(cols)).rounded(.up)))
        let cellW = max(120, (dw - m * (cols + 1)) / cols)
        let cellH = max(80,  (dh - m * (rows + 1)) / rows)
        return sources.enumerated().map { (i, src) in
            let col = i % cols
            let row = i / cols
            return PipPlacement(
                sourceID: src, destinationID: destination,
                size: PipSize(width: cellW, height: cellH),
                position: PipPosition(x: m + col * (cellW + m), y: m + row * (cellH + m)),
                durationMs: durationMs
            )
        }
    }
}

final class PipGridErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var error: Error?
    func set(_ e: Error) { lock.withLock { if error == nil { error = e } } }
    func get() -> Error? { lock.withLock { error } }
}

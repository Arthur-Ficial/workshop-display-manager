import WDMSystem

extension WDMController {
    public struct PipPlan: Equatable, Sendable {
        public let sourceAlias: String
        public let destinationAlias: String?
        public let size: PipSize
        public let position: PipPosition?
        public let flip: Flip
        public let durationMs: Int?
        public let remoteControl: Bool

        public init(
            sourceAlias: String,
            destinationAlias: String? = nil,
            size: PipSize = .defaultSize,
            position: PipPosition? = nil,
            flip: Flip = .none,
            durationMs: Int? = nil,
            remoteControl: Bool = false
        ) {
            self.sourceAlias = sourceAlias
            self.destinationAlias = destinationAlias
            self.size = size
            self.position = position
            self.flip = flip
            self.durationMs = durationMs
            self.remoteControl = remoteControl
        }
    }

    /// Run a single PIP. If `plan.destinationAlias` is nil, defaults to `main`.
    public func pip(plan: PipPlan, using flipper: PipFlipper) throws {
        try mapErrors {
            let snap = try provider.snapshot()
            let sourceID = try DisplayResolver.resolve(plan.sourceAlias, in: snap)
            let destinationID = try resolveDestination(plan: plan, in: snap)
            try flipper.run(
                sourceID: sourceID,
                destinationID: destinationID,
                size: plan.size,
                position: plan.position,
                flip: plan.flip,
                durationMs: plan.durationMs,
                remoteControl: plan.remoteControl
            )
        }
    }

    private func resolveDestination(plan: PipPlan, in snap: Snapshot) throws -> UInt32 {
        if let alias = plan.destinationAlias {
            return try DisplayResolver.resolve(alias, in: snap)
        }
        guard let main = snap.main?.id else {
            throw WDMError.usage("pip: no main display found and no destination specified")
        }
        return main
    }
}

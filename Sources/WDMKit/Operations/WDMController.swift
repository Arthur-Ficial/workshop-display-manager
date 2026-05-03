import WDMCore
import WDMSystem

public struct WDMController: Sendable {
    let provider: DisplayProvider
    let profileStore: ProfileStore
    let env: [String: String]

    public init(
        provider: DisplayProvider,
        profileStore: ProfileStore,
        env: [String: String]
    ) {
        self.provider = provider
        self.profileStore = profileStore
        self.env = env
    }

    public func snapshot() throws -> Snapshot {
        try mapErrors {
            let snap = try provider.snapshot()
            let displays = try DisplayAliasOverlay.apply(
                snap.displays, provider: provider, env: env
            )
            return Snapshot(createdAt: snap.createdAt, displays: displays)
        }
    }

    public func list() throws -> [DisplayInfo] {
        try snapshot().displays
    }

    public func get(_ alias: String) throws -> DisplayInfo {
        try mapErrors {
            let snap = try snapshot()
            let id = try DisplayResolver.resolve(alias, in: snap)
            guard let display = snap.display(id: id) else {
                throw WDMError.displayNotFound(id)
            }
            return display
        }
    }

    public func get(_ alias: String, field: WDMDisplayField) throws -> WDMFieldValue {
        try fieldValue(of: get(alias), field: field)
    }

    public func modes(_ alias: String) throws -> [Mode] {
        try mapErrors {
            let id = try resolve(alias)
            return try provider.modes(for: id)
        }
    }

    public func brightness(_ alias: String) throws -> Float? {
        try mapErrors {
            try provider.brightness(for: resolve(alias))
        }
    }

    public func brightness(_ alias: String, value: Float, confirmer: Confirmer) throws -> ApplyResult {
        try mutate(alias, confirmer: confirmer, description: "Set brightness") { id in
            try provider.setBrightness(displayID: id, value: value, options: .noConfirm)
        }
    }

    public func main(_ alias: String, confirmer: Confirmer) throws -> ApplyResult {
        try mutate(alias, confirmer: confirmer, description: "Set main") { id in
            try provider.setMain(displayID: id, options: .noConfirm)
        }
    }

    public func mode(_ alias: String, mode: Mode, confirmer: Confirmer) throws -> ApplyResult {
        do {
            return try mutate(alias, confirmer: confirmer, description: "Set mode") { id in
                try provider.setMode(displayID: id, mode: mode, options: .noConfirm)
            }
        } catch ProviderError.modeNotSupported {
            throw WDMError.modeNotSupported(mode.description)
        } catch WDMError.modeNotSupported {
            throw WDMError.modeNotSupported(mode.description)
        }
    }

    public func mirror(source: String, targets: [String], confirmer: Confirmer) throws -> ApplyResult {
        try mapErrors {
            let snap = try provider.snapshot()
            let sourceID = try DisplayResolver.resolve(source, in: snap)
            let targetIDs = try targets.map { try DisplayResolver.resolve($0, in: snap) }
            return try safe(confirmer: confirmer, description: "Mirror") {
                try provider.mirror(source: sourceID, targets: targetIDs, options: .noConfirm)
            }
        }
    }

    public func unmirror(_ alias: String, confirmer: Confirmer) throws -> ApplyResult {
        try mutate(alias, confirmer: confirmer, description: "Unmirror") { id in
            try provider.unmirror(displayID: id, options: .noConfirm)
        }
    }

    public func move(_ alias: String, to origin: Point, confirmer: Confirmer) throws -> ApplyResult {
        try mutate(alias, confirmer: confirmer, description: "Move") { id in
            try provider.move(displayID: id, to: origin, options: .noConfirm)
        }
    }

    public func rotate(_ alias: String, degrees: Int, confirmer: Confirmer) throws -> ApplyResult {
        try mutate(alias, confirmer: confirmer, description: "Rotate") { id in
            try provider.rotate(displayID: id, degrees: degrees, options: .noConfirm)
        }
    }

    public func flip(_ alias: String, flip: Flip, confirmer: Confirmer) throws -> ApplyResult {
        try mutate(alias, confirmer: confirmer, description: "Flip") { id in
            try provider.setFlip(displayID: id, flip: flip, options: .noConfirm)
        }
    }

    func resolve(_ alias: String) throws -> UInt32 {
        let snap = try provider.snapshot()
        return try DisplayResolver.resolve(alias, in: snap)
    }
}

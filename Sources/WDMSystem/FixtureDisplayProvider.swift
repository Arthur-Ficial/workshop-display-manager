import Foundation
import WDMCore

public final class FixtureDisplayProvider: DisplayProvider, @unchecked Sendable {
    private let fixtureURL: URL
    private let lock = NSLock()
    private var state: FixtureFile
    private let failOnRotate: Bool

    public init(fixtureURL: URL, failOnRotate: Bool = false) throws {
        self.fixtureURL = fixtureURL
        let data = try Data(contentsOf: fixtureURL)
        self.state = try JSONDecoder().decode(FixtureFile.self, from: data)
        self.failOnRotate = failOnRotate
    }

    public func snapshot() throws -> Snapshot {
        lock.withLock { state.snapshot }
    }

    public func modes(for displayID: UInt32) throws -> [Mode] {
        try lock.withLock {
            guard state.snapshot.display(id: displayID) != nil else {
                throw ProviderError.displayNotFound(displayID)
            }
            return state.availableModes[String(displayID)] ?? []
        }
    }

    public func setMain(displayID: UInt32, options: ApplyOptions) throws -> ApplyResult {
        try mutate { snap in
            guard snap.display(id: displayID) != nil else {
                throw ProviderError.displayNotFound(displayID)
            }
            if snap.main?.id == displayID { return .noChange }
            snap = Snapshot(
                createdAt: snap.createdAt,
                displays: snap.displays.map {
                    DisplayInfo(
                        id: $0.id, name: $0.name,
                        isMain: $0.id == displayID,
                        isOnline: $0.isOnline,
                        mirrorSource: $0.mirrorSource,
                        currentMode: $0.currentMode,
                        origin: $0.origin,
                        rotationDegrees: $0.rotationDegrees
                    )
                }
            )
            return .applied
        }
    }

    public func setMode(displayID: UInt32, mode: Mode, options: ApplyOptions) throws -> ApplyResult {
        try mutate { snap in
            guard let display = snap.display(id: displayID) else {
                throw ProviderError.displayNotFound(displayID)
            }
            let supported = state.availableModes[String(displayID)] ?? []
            guard supported.contains(mode) else { throw ProviderError.modeNotSupported }
            if display.currentMode == mode { return .noChange }
            snap = replace(snap, id: displayID) { d in
                DisplayInfo(
                    id: d.id, name: d.name, isMain: d.isMain, isOnline: d.isOnline,
                    mirrorSource: d.mirrorSource,
                    currentMode: mode,
                    origin: d.origin, rotationDegrees: d.rotationDegrees
                )
            }
            return .applied
        }
    }

    public func mirror(source: UInt32, mirror target: UInt32, options: ApplyOptions) throws -> ApplyResult {
        try mutate { snap in
            guard snap.display(id: source) != nil else { throw ProviderError.displayNotFound(source) }
            guard snap.display(id: target) != nil else { throw ProviderError.displayNotFound(target) }
            snap = replace(snap, id: target) { d in
                DisplayInfo(
                    id: d.id, name: d.name, isMain: d.isMain, isOnline: d.isOnline,
                    mirrorSource: source,
                    currentMode: d.currentMode,
                    origin: d.origin, rotationDegrees: d.rotationDegrees
                )
            }
            return .applied
        }
    }

    public func unmirror(displayID: UInt32, options: ApplyOptions) throws -> ApplyResult {
        try mutate { snap in
            guard let d = snap.display(id: displayID) else { throw ProviderError.displayNotFound(displayID) }
            if d.mirrorSource == nil { return .noChange }
            snap = replace(snap, id: displayID) { d in
                DisplayInfo(
                    id: d.id, name: d.name, isMain: d.isMain, isOnline: d.isOnline,
                    mirrorSource: nil,
                    currentMode: d.currentMode,
                    origin: d.origin, rotationDegrees: d.rotationDegrees
                )
            }
            return .applied
        }
    }

    public func move(displayID: UInt32, to origin: Point, options: ApplyOptions) throws -> ApplyResult {
        try mutate { snap in
            guard let d = snap.display(id: displayID) else { throw ProviderError.displayNotFound(displayID) }
            if d.origin == origin { return .noChange }
            snap = replace(snap, id: displayID) { d in
                DisplayInfo(
                    id: d.id, name: d.name, isMain: d.isMain, isOnline: d.isOnline,
                    mirrorSource: d.mirrorSource,
                    currentMode: d.currentMode,
                    origin: origin, rotationDegrees: d.rotationDegrees
                )
            }
            return .applied
        }
    }

    public func rotate(displayID: UInt32, degrees: Int, options: ApplyOptions) throws -> ApplyResult {
        guard [0, 90, 180, 270].contains(degrees) else { throw ProviderError.invalidRotation(degrees) }
        if failOnRotate {
            // Fault-injection for hot-unplug mid-mutation tests (workshop scenario #50):
            // simulate the cable yanking out after CGBeginDisplayConfiguration but before
            // CGCompleteDisplayConfiguration. The fixture surfaces a typed error and
            // does NOT persist any change, mirroring the safe-tx contract.
            throw ProviderError.configurationFailed(
                "fixture: hot-unplug mid-mutation (WDM_FIXTURE_FAIL_ROTATE=1)"
            )
        }
        return try mutate { snap in
            guard let d = snap.display(id: displayID) else { throw ProviderError.displayNotFound(displayID) }
            if d.rotationDegrees == degrees { return .noChange }
            snap = replace(snap, id: displayID) { d in
                DisplayInfo(
                    id: d.id, name: d.name, isMain: d.isMain, isOnline: d.isOnline,
                    mirrorSource: d.mirrorSource,
                    currentMode: d.currentMode,
                    origin: d.origin, rotationDegrees: degrees
                )
            }
            return .applied
        }
    }

    public func brightness(for displayID: UInt32) throws -> Float? {
        try lock.withLock {
            guard state.snapshot.display(id: displayID) != nil else {
                throw ProviderError.displayNotFound(displayID)
            }
            return state.brightness?[String(displayID)] ?? nil
        }
    }

    public func setBrightness(displayID: UInt32, value: Float, options: ApplyOptions) throws -> ApplyResult {
        guard value >= 0 && value <= 1 else { throw ProviderError.brightnessOutOfRange(value) }
        return try lock.withLock {
            guard state.snapshot.display(id: displayID) != nil else {
                throw ProviderError.displayNotFound(displayID)
            }
            // A nil entry in the brightness table means "this display has no brightness control".
            // Missing key entirely means the fixture was authored before brightness — also unsupported.
            let key = String(displayID)
            guard let table = state.brightness, table.keys.contains(key), table[key] ?? nil != nil else {
                throw ProviderError.brightnessUnsupported(displayID)
            }
            var newTable = table
            newTable[key] = value
            state = FixtureFile(
                snapshot: state.snapshot,
                availableModes: state.availableModes,
                brightness: newTable,
                flip: state.flip
            )
            try persist()
            return .applied
        }
    }

    public func flip(for displayID: UInt32) throws -> Flip {
        try lock.withLock {
            guard state.snapshot.display(id: displayID) != nil else {
                throw ProviderError.displayNotFound(displayID)
            }
            return state.flip?[String(displayID)] ?? .none
        }
    }

    public func setFlip(displayID: UInt32, flip: Flip, options: ApplyOptions) throws -> ApplyResult {
        try lock.withLock {
            guard state.snapshot.display(id: displayID) != nil else {
                throw ProviderError.displayNotFound(displayID)
            }
            let key = String(displayID)
            let current = state.flip?[key] ?? .none
            if current == flip { return .noChange }
            var table = state.flip ?? [:]
            if flip == .none {
                table.removeValue(forKey: key)
            } else {
                table[key] = flip
            }
            state = FixtureFile(
                snapshot: state.snapshot,
                availableModes: state.availableModes,
                brightness: state.brightness,
                flip: table.isEmpty ? nil : table
            )
            try persist()
            return .applied
        }
    }

    // MARK: - Helpers

    private func mutate(_ block: (inout Snapshot) throws -> ApplyResult) throws -> ApplyResult {
        try lock.withLock {
            var snap = state.snapshot
            let result = try block(&snap)
            if result == .applied {
                state = FixtureFile(
                    snapshot: snap,
                    availableModes: state.availableModes,
                    brightness: state.brightness,
                    flip: state.flip
                )
                try persist()
            }
            return result
        }
    }

    private func replace(_ snap: Snapshot, id: UInt32, with transform: (DisplayInfo) -> DisplayInfo) -> Snapshot {
        Snapshot(
            createdAt: snap.createdAt,
            displays: snap.displays.map { $0.id == id ? transform($0) : $0 }
        )
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fixtureURL, options: .atomic)
    }
}

struct FixtureFile: Codable, Sendable {
    var snapshot: Snapshot
    var availableModes: [String: [Mode]]
    var brightness: [String: Float?]?
    var flip: [String: Flip]?
}

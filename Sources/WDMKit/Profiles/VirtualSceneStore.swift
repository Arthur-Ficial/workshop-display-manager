import Foundation
import WDMCore

/// JSON-on-disk store for virtual-display scene definitions: a list of
/// `VirtualDisplaySpec`s saved under `~/.config/wdm/virtual-scenes/<name>.json`.
/// Mirrors `ProfileStore` shape — copy + rename. Override path via env
/// `WDM_VIRTUAL_SCENES_DIR` (used by tests and the LaunchAgent flow).
public final class VirtualSceneStore: @unchecked Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func resolve(env: [String: String]) -> VirtualSceneStore {
        if let p = env["WDM_VIRTUAL_SCENES_DIR"], !p.isEmpty {
            return VirtualSceneStore(directory: URL(fileURLWithPath: p))
        }
        let home = (env["HOME"]).map(URL.init(fileURLWithPath:))
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return VirtualSceneStore(
            directory: home.appendingPathComponent(".config/wdm/virtual-scenes")
        )
    }

    private func ensureDir() throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
    }

    private func url(for name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }

    public func save(name: String, specs: [VirtualDisplaySpec]) throws {
        try ensureDir()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(specs)
        try data.write(to: url(for: name), options: .atomic)
    }

    public func load(name: String) throws -> [VirtualDisplaySpec] {
        let path = url(for: name)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw CLIError.profileNotFound(name)
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode([VirtualDisplaySpec].self, from: data)
    }

    public func remove(name: String) throws {
        let path = url(for: name)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw CLIError.profileNotFound(name)
        }
        try FileManager.default.removeItem(at: path)
    }

    public func list() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        return entries
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
            .sorted()
    }
}

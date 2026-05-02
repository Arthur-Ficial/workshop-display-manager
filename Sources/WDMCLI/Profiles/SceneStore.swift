import Foundation
import WDMCore

/// JSON-on-disk store for multi-display scenes (`[SceneEntry]`).
/// Default path: `~/.config/wdm/scenes/<name>.json`.
/// Override via `WDM_SCENES_DIR` (used by tests).
public final class SceneStore: @unchecked Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public static func resolve(env: [String: String]) -> SceneStore {
        if let p = env["WDM_SCENES_DIR"], !p.isEmpty {
            return SceneStore(directory: URL(fileURLWithPath: p))
        }
        let home = (env["HOME"]).map(URL.init(fileURLWithPath:))
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return SceneStore(directory: home.appendingPathComponent(".config/wdm/scenes"))
    }

    private func url(for name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }

    public func load(name: String) throws -> [SceneEntry] {
        let path = url(for: name)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw CLIError.profileNotFound(name)
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode([SceneEntry].self, from: data)
    }

    public func list() -> [String] {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        return entries
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
            .sorted()
    }
}

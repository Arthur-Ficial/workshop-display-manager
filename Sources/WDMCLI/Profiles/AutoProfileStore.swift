import Foundation
import WDMCore

/// Wrapper around `ProfileStore` that places auto-keyed profiles under a
/// dedicated `auto/` subdirectory and computes the filename from the
/// EDID-set hash of the displays in the snapshot.
public final class AutoProfileStore: @unchecked Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func resolve(from store: ProfileStore) -> AutoProfileStore {
        AutoProfileStore(directory: store.directory.appendingPathComponent("auto"))
    }

    public func save(_ snapshot: Snapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let key = EDIDHasher.hash(of: snapshot.displays)
        let url = directory.appendingPathComponent("\(key).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public func load(matching displays: [DisplayInfo]) throws -> Snapshot? {
        let key = EDIDHasher.hash(of: displays)
        let url = directory.appendingPathComponent("\(key).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Snapshot.self, from: data)
    }
}

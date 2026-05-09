import Foundation

/// Stable JSON serialisation for `SceneTree`. Keys sorted; pretty-printable.
public enum SceneTreeJSON {
    public static func encode(_ tree: SceneTree, pretty: Bool = false) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        return try enc.encode(tree)
    }

    public static func decode(_ data: Data) throws -> SceneTree {
        try JSONDecoder().decode(SceneTree.self, from: data)
    }
}

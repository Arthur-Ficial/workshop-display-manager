import Foundation

public enum ActionResultJSON {
    public static func encode(_ result: ActionResult) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(result)
    }
}

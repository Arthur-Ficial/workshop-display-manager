import Foundation

public enum JSONFormatter {
    public static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return (String(data: data, encoding: .utf8) ?? "") + "\n"
    }
}

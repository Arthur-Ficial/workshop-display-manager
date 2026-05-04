import Foundation

/// Decodes a JSON body into a `RemoteAction`. Wire format is
/// `{"action": "click", "ref": "@e2"}` etc. so it stays trivial to construct
/// from a shell pipeline (`echo '{"action":"click","ref":"@e2"}' | curl …`).
public enum RemoteActionJSON {
    public enum DecodeError: Error, Equatable, CustomStringConvertible {
        case missingKey(String)
        case unknownAction(String)
        case invalidRef(String)
        case malformed(String)

        public var description: String {
            switch self {
            case .missingKey(let k): "missing key: \(k)"
            case .unknownAction(let a): "unknown action: \(a)"
            case .invalidRef(let r): "invalid ref: \(r)"
            case .malformed(let m): "malformed body: \(m)"
            }
        }
    }

    public static func decode(_ data: Data) throws -> RemoteAction {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodeError.malformed("body is not a JSON object")
        }
        return try decode(object: obj)
    }

    public static func decode(object obj: [String: Any]) throws -> RemoteAction {
        guard let action = obj["action"] as? String else { throw DecodeError.missingKey("action") }
        switch action {
        case "click":    return .click(ref: try ref(obj))
        case "dblclick": return .dblclick(ref: try ref(obj))
        case "hover":    return .hover(ref: try ref(obj))
        case "focus":    return .focus(ref: try ref(obj))
        case "press":
            guard let key = obj["key"] as? String else { throw DecodeError.missingKey("key") }
            return .press(key: key)
        case "fill":
            guard let text = obj["text"] as? String else { throw DecodeError.missingKey("text") }
            return .fill(ref: try ref(obj), text: text)
        default: throw DecodeError.unknownAction(action)
        }
    }

    private static func ref(_ obj: [String: Any]) throws -> Ref {
        guard let raw = obj["ref"] as? String else { throw DecodeError.missingKey("ref") }
        guard let r = Ref(raw) else { throw DecodeError.invalidRef(raw) }
        return r
    }
}

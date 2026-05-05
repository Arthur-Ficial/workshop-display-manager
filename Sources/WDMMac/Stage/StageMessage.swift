import Foundation

/// Messages the embedded WebKit Stage posts back to Swift via
/// `window.webkit.messageHandlers.wdm.postMessage(...)`. Decoded from a
/// JSON object with a discriminator `type` field. Unknown types are
/// dropped — additive evolution.
public enum StageMessage: Equatable, Sendable {
    case ready
    case select(id: UInt32)
    case dragEnd(id: UInt32, originX: Int, originY: Int)
    case zoom(value: Double)

    /// Build from a `[String: Any]` decoded out of WKScriptMessage.body.
    public init?(json: [String: Any]) {
        guard let type = json["type"] as? String else { return nil }
        switch type {
        case "ready":
            self = .ready
        case "select":
            guard let id = json["id"] as? Int else { return nil }
            self = .select(id: UInt32(id))
        case "drag":
            guard json["phase"] as? String == "end",
                  let id = json["id"] as? Int,
                  let x = json["originX"] as? Int,
                  let y = json["originY"] as? Int else { return nil }
            self = .dragEnd(id: UInt32(id), originX: x, originY: y)
        case "zoom":
            guard let v = json["value"] as? Double else { return nil }
            self = .zoom(value: v)
        default:
            return nil
        }
    }
}

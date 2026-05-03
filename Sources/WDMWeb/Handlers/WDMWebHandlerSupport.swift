import Foundation
import WDMKit

/// Shared helpers for WDMWeb handlers: error mapping, JSON encode/decode.
public enum WDMWebHandlerSupport {
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    public static let decoder = JSONDecoder()

    /// Map a `WDMError` to an HTTP status. Stable contract — frontends rely on it.
    public static func httpStatus(for error: WDMError) -> Int {
        switch error {
        case .usage, .hotkeyChordMalformed: return 400
        case .displayNotFound, .virtualNotFound, .profileNotFound, .sceneNotFound:
            return 404
        case .modeNotSupported, .ddcUnsupported, .edidUnavailable: return 422
        case .hotkeyChordTaken, .cancelled: return 409
        case .ioError, .virtualSpawnFailed: return 500
        case .coreGraphicsError, .displayCaptureFailed: return 500
        }
    }

    /// Run a throwing closure and translate any `WDMError` to a structured
    /// JSON error response with the right HTTP status.
    public static func run(_ body: () throws -> WDMWebResponse) -> WDMWebResponse {
        do {
            return try body()
        } catch let error as WDMError {
            return WDMWebResponse.error(status: httpStatus(for: error), message: error.message)
        } catch {
            return WDMWebResponse.error(status: 500, message: "\(error)")
        }
    }

    public static func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    public static func decodeBody<T: Decodable>(_ type: T.Type, _ request: WDMWebRequest) throws -> T {
        try decoder.decode(type, from: request.body)
    }
}

import Foundation

public struct WDMWebResponse: Sendable, Equatable {
    public let status: Int
    public let body: Data
    public let contentType: String

    public init(status: Int, body: Data, contentType: String = "application/json") {
        self.status = status
        self.body = body
        self.contentType = contentType
    }

    public static func ok(_ json: Data) -> WDMWebResponse {
        WDMWebResponse(status: 200, body: json)
    }

    public static func okText(_ text: String) -> WDMWebResponse {
        WDMWebResponse(status: 200, body: Data(text.utf8), contentType: "text/plain; charset=utf-8")
    }

    public static func error(status: Int, message: String) -> WDMWebResponse {
        let payload = #"{"error":"\#(escape(message))"}"#
        return WDMWebResponse(status: status, body: Data(payload.utf8))
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    public func encode() -> Data {
        let reason = Self.reasonPhrase(status)
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(body)
        return data
    }

    static func reasonPhrase(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 409: return "Conflict"
        case 422: return "Unprocessable Entity"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default:  return "Status"
        }
    }
}

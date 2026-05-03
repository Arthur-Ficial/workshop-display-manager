import Foundation

public struct WDMWebRequest: Sendable, Equatable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data

    public init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public enum WDMWebRequestError: Error, Equatable, Sendable {
    case malformed(String)
    case incomplete
    case bodyTooLarge(Int)
}

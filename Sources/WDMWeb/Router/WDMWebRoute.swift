import Foundation

/// One declared route: HTTP method + path pattern + handler.
public struct WDMWebRoute: Sendable {
    public let method: String
    public let pattern: String
    public let handler: @Sendable (WDMWebRequest, [String: String], WDMWebDeps) throws -> WDMWebResponse

    public init(
        method: String,
        pattern: String,
        handler: @escaping @Sendable (WDMWebRequest, [String: String], WDMWebDeps) throws -> WDMWebResponse
    ) {
        self.method = method
        self.pattern = pattern
        self.handler = handler
    }
}

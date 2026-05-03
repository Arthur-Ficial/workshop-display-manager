import Foundation

/// Trivial path-pattern matcher: literal segments + `{name}` captures.
/// Methods are matched verbatim. No regex, no globbing.
public struct WDMWebRouter: Sendable {
    public struct Match: Sendable {
        public let route: WDMWebRoute
        public let pathParams: [String: String]
    }

    public let routes: [WDMWebRoute]

    public init(routes: [WDMWebRoute]) { self.routes = routes }

    public func match(method: String, path: String) -> Match? {
        let pathSegments = Self.split(path)
        for route in routes where route.method == method {
            let routeSegments = Self.split(route.pattern)
            if let params = Self.match(route: routeSegments, against: pathSegments) {
                return Match(route: route, pathParams: params)
            }
        }
        return nil
    }

    static func split(_ path: String) -> [String] {
        let trimmed = path.split(separator: "?").first.map(String.init) ?? path
        return trimmed.split(separator: "/").map(String.init)
    }

    static func match(route: [String], against actual: [String]) -> [String: String]? {
        guard route.count == actual.count else { return nil }
        var params: [String: String] = [:]
        for (r, a) in zip(route, actual) {
            if r.hasPrefix("{") && r.hasSuffix("}") {
                let name = String(r.dropFirst().dropLast())
                params[name] = a
            } else if r != a {
                return nil
            }
        }
        return params
    }
}

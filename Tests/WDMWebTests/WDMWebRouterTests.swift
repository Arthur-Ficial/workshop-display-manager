import Testing
@testable import WDMWeb

@Suite("WDMWebRouter")
struct WDMWebRouterTests {
    @Test("matches a literal path on the right method")
    func literal() {
        let router = WDMWebRouter(routes: [
            WDMWebRoute(method: "GET", pattern: "/displays") { _, _, _ in .okText("ok") }
        ])
        #expect(router.match(method: "GET", path: "/displays") != nil)
        #expect(router.match(method: "POST", path: "/displays") == nil)
        #expect(router.match(method: "GET", path: "/other") == nil)
    }

    @Test("captures {alias} into params")
    func captures() {
        let router = WDMWebRouter(routes: [
            WDMWebRoute(method: "GET", pattern: "/displays/{alias}/modes") { _, _, _ in .okText("ok") }
        ])
        let m = router.match(method: "GET", path: "/displays/main/modes")
        #expect(m?.pathParams == ["alias": "main"])
    }

    @Test("query string is ignored when matching")
    func ignoresQuery() {
        let router = WDMWebRouter(routes: [
            WDMWebRoute(method: "GET", pattern: "/displays") { _, _, _ in .okText("ok") }
        ])
        #expect(router.match(method: "GET", path: "/displays?foo=bar") != nil)
    }
}

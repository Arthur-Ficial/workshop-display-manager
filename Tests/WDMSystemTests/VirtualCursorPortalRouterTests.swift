import CoreGraphics
import Testing
@testable import WDMSystem

@Suite("Virtual cursor portal router")
struct VirtualCursorPortalRouterTests {

    @Test("routes leftward motion from physical edge into adjacent virtual display")
    func routesIntoVirtual() {
        let router = VirtualCursorPortalRouter(targetDisplayID: 70)
        let displays = [
            VirtualCursorPortalRouter.Display(
                id: 1,
                bounds: CGRect(x: 0, y: 0, width: 1470, height: 956)
            ),
            VirtualCursorPortalRouter.Display(
                id: 70,
                bounds: CGRect(x: -1320, y: 0, width: 1320, height: 2868)
            ),
        ]

        let route = router.route(
            location: CGPoint(x: 0, y: 400),
            delta: CGVector(dx: -6, dy: 0),
            displays: displays
        )

        #expect(route?.displayID == 70)
        #expect(route?.globalPoint == CGPoint(x: -1, y: 400))
        #expect(route?.localPoint == CGPoint(x: 1319, y: 400))
    }

    @Test("routes rightward motion from virtual edge back into physical display")
    func routesOutOfVirtual() {
        let router = VirtualCursorPortalRouter(targetDisplayID: 70)
        let displays = [
            VirtualCursorPortalRouter.Display(
                id: 1,
                bounds: CGRect(x: 0, y: 0, width: 1470, height: 956)
            ),
            VirtualCursorPortalRouter.Display(
                id: 70,
                bounds: CGRect(x: -1320, y: 0, width: 1320, height: 2868)
            ),
        ]

        let route = router.route(
            location: CGPoint(x: -1, y: 400),
            delta: CGVector(dx: 7, dy: 0),
            displays: displays
        )

        #expect(route?.displayID == 1)
        #expect(route?.globalPoint == CGPoint(x: 1, y: 400))
        #expect(route?.localPoint == CGPoint(x: 1, y: 400))
    }

    @Test("does not route across a coordinate gap")
    func gapDoesNotRoute() {
        let router = VirtualCursorPortalRouter(targetDisplayID: 70)
        let displays = [
            VirtualCursorPortalRouter.Display(
                id: 1,
                bounds: CGRect(x: 0, y: 0, width: 1470, height: 956)
            ),
            VirtualCursorPortalRouter.Display(
                id: 70,
                bounds: CGRect(x: -1320, y: 0, width: 1000, height: 2868)
            ),
        ]

        let route = router.route(
            location: CGPoint(x: 0, y: 400),
            delta: CGVector(dx: -6, dy: 0),
            displays: displays
        )

        #expect(route == nil)
    }
}

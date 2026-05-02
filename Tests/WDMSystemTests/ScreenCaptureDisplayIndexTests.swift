import CoreGraphics
import Testing
@testable import WDMSystem

@Suite("ScreenCaptureDisplayIndex")
struct ScreenCaptureDisplayIndexTests {
    @Test("screencapture index is 1-based active-display order")
    func mapsActiveDisplayOrder() throws {
        let ids: [CGDirectDisplayID] = [101, 202, 303]
        let index = try ScreenCaptureDisplayIndex.screencaptureIndex(
            displayID: 202,
            activeDisplays: ids
        )
        #expect(index == 2)
    }

    @Test("missing display throws display-not-found")
    func missingDisplayThrows() {
        #expect(throws: ProviderError.self) {
            try ScreenCaptureDisplayIndex.screencaptureIndex(
                displayID: 404,
                activeDisplays: [101, 202, 303]
            )
        }
    }
}

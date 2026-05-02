import Testing
import Foundation
@testable import WDMCore

@Suite("VirtualDisplaySpec")
struct VirtualDisplaySpecTests {

    @Test("memberwise init exposes every documented field")
    func init_() {
        let s = VirtualDisplaySpec(
            name: "Workshop Demo",
            width: 1920, height: 1080, refreshHz: 60,
            hiDPI: true,
            widthMM: 600, heightMM: 340
        )
        #expect(s.name == "Workshop Demo")
        #expect(s.width == 1920)
        #expect(s.height == 1080)
        #expect(s.refreshHz == 60)
        #expect(s.hiDPI == true)
        #expect(s.widthMM == 600)
        #expect(s.heightMM == 340)
    }

    @Test("default mode is 1920x1080 @ 60, hiDPI on, ~600×340mm (24-inch 16:9)")
    func defaults() {
        let s = VirtualDisplaySpec.defaultSpec(name: "X")
        #expect(s.name == "X")
        #expect(s.width == 1920)
        #expect(s.height == 1080)
        #expect(s.refreshHz == 60)
        #expect(s.hiDPI == true)
        #expect(s.widthMM == 600)
        #expect(s.heightMM == 340)
    }

    @Test("parseMode accepts WxH@Hz form")
    func parseMode() {
        let m = VirtualDisplaySpec.parseMode("1920x1080@60")
        #expect(m?.width == 1920)
        #expect(m?.height == 1080)
        #expect(m?.refreshHz == 60)

        let m2 = VirtualDisplaySpec.parseMode("3840x2160@120")
        #expect(m2?.width == 3840)
        #expect(m2?.height == 2160)
        #expect(m2?.refreshHz == 120)
    }

    @Test("parseMode rejects malformed input")
    func parseModeBad() {
        #expect(VirtualDisplaySpec.parseMode("huge") == nil)
        #expect(VirtualDisplaySpec.parseMode("1920x1080") == nil)        // no refresh
        #expect(VirtualDisplaySpec.parseMode("1920@60") == nil)          // no x
        #expect(VirtualDisplaySpec.parseMode("0x1080@60") == nil)        // zero width
        #expect(VirtualDisplaySpec.parseMode("1920x0@60") == nil)        // zero height
        #expect(VirtualDisplaySpec.parseMode("1920x1080@0") == nil)      // zero refresh
        #expect(VirtualDisplaySpec.parseMode("-1920x1080@60") == nil)    // negative
    }

    @Test("parseSize accepts WxH form")
    func parseSize() {
        let s = VirtualDisplaySpec.parseSize("1920x1080")
        #expect(s?.width == 1920)
        #expect(s?.height == 1080)
        #expect(VirtualDisplaySpec.parseSize("huge") == nil)
        #expect(VirtualDisplaySpec.parseSize("0x1080") == nil)
    }

    @Test("Codable round-trips through JSON")
    func codable() throws {
        let s = VirtualDisplaySpec(
            name: "Round-Trip",
            width: 2560, height: 1440, refreshHz: 75,
            hiDPI: false, widthMM: 800, heightMM: 450
        )
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(VirtualDisplaySpec.self, from: data)
        #expect(decoded == s)
    }
}

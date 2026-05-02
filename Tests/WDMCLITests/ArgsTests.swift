import Testing
@testable import WDMCLI

@Suite("Args")
struct ArgsTests {
    @Test("flagString returns the token after a flag")
    func flagString() {
        #expect(Args.flagString(["--out", "/tmp/a.png"], name: "--out") == "/tmp/a.png")
    }

    @Test("flagString ignores missing or valueless flags")
    func missingFlagString() {
        #expect(Args.flagString(["--out"], name: "--out") == nil)
        #expect(Args.flagString(["--other", "x"], name: "--out") == nil)
    }

    @Test("flagInt parses integer flag values")
    func flagInt() {
        #expect(Args.flagInt(["--duration-ms", "250"], name: "--duration-ms") == 250)
        #expect(Args.flagInt(["--duration-ms", "nope"], name: "--duration-ms") == nil)
    }
}

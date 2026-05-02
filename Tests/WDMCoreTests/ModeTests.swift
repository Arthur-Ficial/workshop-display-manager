import Testing
@testable import WDMCore

@Suite("Mode")
struct ModeTests {

    @Test("parses canonical WIDTHxHEIGHT@HZ")
    func parsesCanonical() throws {
        let mode = try Mode.parse("1920x1080@60")
        #expect(mode.width == 1920)
        #expect(mode.height == 1080)
        #expect(mode.refreshHz == 60)
    }

    @Test("parses fractional refresh (59.94)")
    func parsesFractionalRefresh() throws {
        let mode = try Mode.parse("1920x1080@59.94")
        #expect(mode.width == 1920)
        #expect(mode.height == 1080)
        #expect(abs(mode.refreshHz - 59.94) < 0.001)
    }

    @Test("rejects missing @")
    func rejectsMissingAt() {
        #expect(throws: Mode.ParseError.self) {
            _ = try Mode.parse("1920x1080")
        }
    }

    @Test("rejects bad dimensions")
    func rejectsBadDimensions() {
        #expect(throws: Mode.ParseError.self) {
            _ = try Mode.parse("1920@60")
        }
    }

    @Test("rejects non-numeric components")
    func rejectsNonNumeric() {
        #expect(throws: Mode.ParseError.self) {
            _ = try Mode.parse("abcxdef@60")
        }
    }

    @Test("rejects zero or negative")
    func rejectsZero() {
        #expect(throws: Mode.ParseError.self) {
            _ = try Mode.parse("0x1080@60")
        }
        #expect(throws: Mode.ParseError.self) {
            _ = try Mode.parse("1920x1080@0")
        }
    }

    @Test("formats round-trip")
    func formatsRoundTrip() throws {
        let mode = Mode(width: 2560, height: 1440, refreshHz: 60)
        #expect(mode.description == "2560x1440@60")
    }

    @Test("formats fractional refresh round-trip")
    func formatsFractionalRefresh() throws {
        let mode = Mode(width: 1920, height: 1080, refreshHz: 59.94)
        #expect(mode.description == "1920x1080@59.94")
    }

    @Test("equality")
    func equality() {
        #expect(Mode(width: 1920, height: 1080, refreshHz: 60)
                == Mode(width: 1920, height: 1080, refreshHz: 60))
        #expect(Mode(width: 1920, height: 1080, refreshHz: 60)
                != Mode(width: 1920, height: 1080, refreshHz: 59.94))
    }
}

import Testing
@testable import WDMKit

@Suite("WDMError new typed cases")
struct WDMErrorCasesTests {
    @Test("displayCaptureFailed maps to coreGraphicsError exit code with id in message")
    func displayCaptureFailed() {
        let err = WDMError.displayCaptureFailed(7)
        #expect(err.exitCode == ExitCodes.coreGraphicsError)
        #expect(err.message.contains("7"))
    }

    @Test("hotkeyChordTaken maps to ioError exit code and names the chord")
    func hotkeyChordTaken() {
        let err = WDMError.hotkeyChordTaken("ctrl+alt+1")
        #expect(err.exitCode == ExitCodes.ioError)
        #expect(err.message.contains("ctrl+alt+1"))
    }

    @Test("hotkeyChordMalformed maps to usage exit code and names the chord")
    func hotkeyChordMalformed() {
        let err = WDMError.hotkeyChordMalformed("ctrl++")
        #expect(err.exitCode == ExitCodes.usage)
        #expect(err.message.contains("ctrl++"))
    }

    @Test("virtualSpawnFailed maps to ioError and includes the reason")
    func virtualSpawnFailed() {
        let err = WDMError.virtualSpawnFailed("pgrep failed")
        #expect(err.exitCode == ExitCodes.ioError)
        #expect(err.message.contains("pgrep failed"))
    }

    @Test("virtualNotFound maps to profileNotFound and names the target")
    func virtualNotFound() {
        let err = WDMError.virtualNotFound("ipad-pro")
        #expect(err.exitCode == ExitCodes.profileNotFound)
        #expect(err.message.contains("ipad-pro"))
    }

    @Test("edidUnavailable maps to modeNotSupported and names the display")
    func edidUnavailable() {
        let err = WDMError.edidUnavailable(42)
        #expect(err.exitCode == ExitCodes.modeNotSupported)
        #expect(err.message.contains("42"))
    }

    @Test("sceneNotFound maps to profileNotFound and names the scene")
    func sceneNotFound() {
        let err = WDMError.sceneNotFound("workshop")
        #expect(err.exitCode == ExitCodes.profileNotFound)
        #expect(err.message.contains("workshop"))
    }
}

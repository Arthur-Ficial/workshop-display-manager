import Testing
@testable import WDMSystem

@Suite("PermissionProbe")
struct PermissionProbeTests {
    @Test("accessibility message is canonical")
    func accessibilityMessage() {
        let message = PermissionProbe.accessibilityMessage(context: "pip --remote")
        #expect(message.contains("pip --remote: Accessibility permission not granted"))
        #expect(message.contains("Privacy & Security → Accessibility"))
    }

    @Test("screen recording message is canonical")
    func screenRecordingMessage() {
        let message = PermissionProbe.screenRecordingMessage(context: "pip")
        #expect(message.contains("pip: Screen Recording permission not granted"))
        #expect(message.contains("Privacy & Security → Screen Recording"))
    }
}

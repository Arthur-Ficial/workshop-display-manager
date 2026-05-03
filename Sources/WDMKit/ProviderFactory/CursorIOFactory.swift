import Foundation
import WDMSystem

/// Picks the `CursorIO` impl. For now there is no env-driven test override —
/// hermetic tests inject `RecordingCursorIO` directly into the Kit op.
public enum CursorIOFactory {
    public static func make(env: [String: String]) -> CursorIO { RealCursorIO() }
}

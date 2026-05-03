import Foundation

/// Protocol layer between `wdm hotkeys daemon` and the underlying global
/// hotkey API (Carbon's `RegisterEventHotKey` on real macOS, a recording
/// fixture in tests). Modular by design: the daemon code never imports
/// Carbon, the recording impl never imports AppKit.
public protocol HotkeyRegistrar: Sendable {
    /// Register a chord (already-normalized via `Keybinding.normalize`).
    /// Throws if the chord is malformed or the OS reports it as taken.
    func register(chord: String) throws

    /// Run the hotkey loop. Calls `onFire` whenever a registered chord is
    /// pressed. Returns when `maxEvents` chords have fired (if set), or
    /// when the process is terminated. `maxEvents == 0` means "register
    /// only, don't wait for any events" — used by tests to assert
    /// registration without waiting on real key presses.
    func run(maxEvents: Int?, onFire: @escaping (String) -> Void)
}

public enum HotkeyRegistrarError: Error, Equatable, Sendable {
    case malformedChord(String)
    case chordTaken(String)
    case carbonFailure(String)
}

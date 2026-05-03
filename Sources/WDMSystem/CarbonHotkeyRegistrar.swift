import Foundation
#if canImport(Carbon)
import Carbon.HIToolbox
#endif

/// Production `HotkeyRegistrar` using Carbon's `RegisterEventHotKey` —
/// the only public global-hotkey API on macOS. Maps a normalized chord
/// (`cmd+ctrl+shift+s`) to a Carbon `(virtualKeyCode, modifierMask)`
/// pair, installs an application-level event handler, and runs the
/// CFRunLoop.
public final class CarbonHotkeyRegistrar: HotkeyRegistrar, @unchecked Sendable {
    public init() {}

    #if canImport(Carbon)
    private final class State {
        var idToChord: [UInt32: String] = [:]
        var nextID: UInt32 = 1
        var onFire: ((String) -> Void)?
        var fired: Int = 0
        var maxEvents: Int = .max
    }
    private let state = State()

    public func register(chord: String) throws {
        let (key, mods) = try Self.parse(chord: chord)
        var hotKeyRef: EventHotKeyRef?
        let id = state.nextID
        state.nextID += 1
        let hkID = EventHotKeyID(signature: OSType(0x57444D48 /* 'WDMH' */), id: id)
        let status = RegisterEventHotKey(
            UInt32(key), UInt32(mods),
            hkID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard status == noErr else {
            if status == OSStatus(eventHotKeyExistsErr) {
                throw HotkeyRegistrarError.chordTaken(chord)
            }
            throw HotkeyRegistrarError.carbonFailure("RegisterEventHotKey: \(status)")
        }
        state.idToChord[id] = chord
    }

    public func run(maxEvents: Int?, onFire: @escaping (String) -> Void) {
        state.onFire = onFire
        state.maxEvents = maxEvents ?? .max
        if maxEvents == 0 { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(state).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            var hkID = EventHotKeyID()
            let r = GetEventParameter(
                eventRef, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hkID
            )
            guard r == noErr else { return noErr }
            let st = Unmanaged<State>.fromOpaque(userData).takeUnretainedValue()
            if let chord = st.idToChord[hkID.id] {
                st.onFire?(chord)
                st.fired += 1
                if st.fired >= st.maxEvents {
                    CFRunLoopStop(CFRunLoopGetCurrent())
                }
            }
            return noErr
        }, 1, &spec, context, nil)
        CFRunLoopRun()
    }

    private static func parse(chord: String) throws -> (key: Int, mods: Int) {
        let parts = chord.split(separator: "+").map(String.init)
        guard parts.count >= 2, let last = parts.last else {
            throw HotkeyRegistrarError.malformedChord(chord)
        }
        var mods = 0
        for m in parts.dropLast() {
            switch m {
            case "cmd":   mods |= cmdKey
            case "ctrl":  mods |= controlKey
            case "opt":   mods |= optionKey
            case "shift": mods |= shiftKey
            case "fn":    break // Carbon has no fn flag for hotkeys
            default: throw HotkeyRegistrarError.malformedChord(chord)
            }
        }
        guard let key = Self.virtualKey(for: last) else {
            throw HotkeyRegistrarError.malformedChord(chord)
        }
        return (key, mods)
    }

    private static let keyMap: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
        "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
        "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
        "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
        "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "space": kVK_Space, "return": kVK_Return, "tab": kVK_Tab,
        "escape": kVK_Escape, "esc": kVK_Escape, "delete": kVK_Delete,
        "arrow-left": kVK_LeftArrow, "arrow-right": kVK_RightArrow,
        "arrow-up": kVK_UpArrow, "arrow-down": kVK_DownArrow,
        "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4,
        "f5": kVK_F5, "f6": kVK_F6, "f7": kVK_F7, "f8": kVK_F8,
        "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
    ]

    private static func virtualKey(for token: String) -> Int? {
        keyMap[token]
    }

    #else
    public func register(chord: String) throws {
        throw HotkeyRegistrarError.carbonFailure("Carbon framework not available")
    }
    public func run(maxEvents: Int?, onFire: @escaping (String) -> Void) {}
    #endif
}

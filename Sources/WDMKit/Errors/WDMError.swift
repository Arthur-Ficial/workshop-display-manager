public enum WDMError: Error, Equatable, Sendable {
    case usage(String)
    case displayNotFound(UInt32)
    case modeNotSupported(String)
    case cancelled
    case profileNotFound(String)
    case ioError(String)
    case coreGraphicsError(String)
    case ddcUnsupported(UInt32)
    case displayCaptureFailed(UInt32)
    case hotkeyChordTaken(String)
    case hotkeyChordMalformed(String)
    case virtualSpawnFailed(String)
    case virtualNotFound(String)
    case edidUnavailable(UInt32)
    case sceneNotFound(String)

    public var exitCode: Int32 {
        switch self {
        case .usage:               return ExitCodes.usage
        case .displayNotFound:     return ExitCodes.displayNotFound
        case .modeNotSupported:    return ExitCodes.modeNotSupported
        case .cancelled:           return ExitCodes.cancelled
        case .profileNotFound:     return ExitCodes.profileNotFound
        case .ioError:             return ExitCodes.ioError
        case .coreGraphicsError:   return ExitCodes.coreGraphicsError
        case .ddcUnsupported:      return ExitCodes.modeNotSupported
        case .displayCaptureFailed: return ExitCodes.coreGraphicsError
        case .hotkeyChordTaken:    return ExitCodes.ioError
        case .hotkeyChordMalformed: return ExitCodes.usage
        case .virtualSpawnFailed:  return ExitCodes.ioError
        case .virtualNotFound:     return ExitCodes.profileNotFound
        case .edidUnavailable:     return ExitCodes.modeNotSupported
        case .sceneNotFound:       return ExitCodes.profileNotFound
        }
    }

    public var message: String {
        switch self {
        case .usage(let s):              return s
        case .displayNotFound(let id):   return "display not found: \(id)"
        case .modeNotSupported(let s):   return "mode not supported: \(s)"
        case .cancelled:                 return "cancelled"
        case .profileNotFound(let s):    return "profile not found: \(s)"
        case .ioError(let s):            return "I/O error: \(s)"
        case .coreGraphicsError(let s):  return "CoreGraphics error: \(s)"
        case .ddcUnsupported(let id):    return Self.ddcUnsupportedMessage(id)
        case .displayCaptureFailed(let id): return "display capture failed: \(id)"
        case .hotkeyChordTaken(let c):   return "hotkey chord already registered: \(c)"
        case .hotkeyChordMalformed(let c): return "malformed hotkey chord: \(c)"
        case .virtualSpawnFailed(let s): return "virtual display spawn failed: \(s)"
        case .virtualNotFound(let s):    return "virtual display not found: \(s)"
        case .edidUnavailable(let id):   return "no EDID for display \(id)"
        case .sceneNotFound(let s):      return "scene not found: \(s)"
        }
    }

    private static func ddcUnsupportedMessage(_ id: UInt32) -> String {
        "ddc: display \(id) does not expose DDC/CI (built-in display, AirPlay, or this Mac's port doesn't support DDC writes)"
    }
}

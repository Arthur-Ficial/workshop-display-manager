public enum CLIError: Error, Equatable {
    case usage(String)
    case displayNotFound(UInt32)
    case modeNotSupported(String)
    case cancelled
    case profileNotFound(String)
    case ioError(String)
    case coreGraphicsError(String)

    public var exitCode: Int32 {
        switch self {
        case .usage:               return ExitCodes.usage
        case .displayNotFound:     return ExitCodes.displayNotFound
        case .modeNotSupported:    return ExitCodes.modeNotSupported
        case .cancelled:           return ExitCodes.cancelled
        case .profileNotFound:     return ExitCodes.profileNotFound
        case .ioError:             return ExitCodes.ioError
        case .coreGraphicsError:   return ExitCodes.coreGraphicsError
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
        }
    }
}

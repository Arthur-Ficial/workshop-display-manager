public enum ProviderError: Error, Equatable, Sendable {
    case displayNotFound(UInt32)
    case modeNotSupported
    case invalidRotation(Int)
    case brightnessUnsupported(UInt32)
    case brightnessOutOfRange(Float)
    case configurationFailed(String)
    case ioError(String)
    case edidUnavailable(UInt32)
}

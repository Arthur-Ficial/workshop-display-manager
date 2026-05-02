public enum ProviderError: Error, Equatable, Sendable {
    case displayNotFound(UInt32)
    case modeNotSupported
    case invalidRotation(Int)
    case configurationFailed(String)
    case ioError(String)
}

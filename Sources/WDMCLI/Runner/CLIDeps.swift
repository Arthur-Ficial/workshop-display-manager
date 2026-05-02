import WDMSystem

public struct CLIDeps: Sendable {
    public let provider: DisplayProvider
    public let profileStore: ProfileStore
    public let confirmer: Confirmer
    public let nativeConfirmer: Confirmer
    public let stdout: OutputWriter
    public let stderr: OutputWriter

    public init(
        provider: DisplayProvider,
        profileStore: ProfileStore,
        confirmer: Confirmer,
        nativeConfirmer: Confirmer,
        stdout: OutputWriter,
        stderr: OutputWriter
    ) {
        self.provider = provider
        self.profileStore = profileStore
        self.confirmer = confirmer
        self.nativeConfirmer = nativeConfirmer
        self.stdout = stdout
        self.stderr = stderr
    }
}

import Foundation
import WDMSystem

public struct CLIDeps: Sendable {
    public let provider: DisplayProvider
    public let profileStore: ProfileStore
    public let confirmer: Confirmer
    public let nativeConfirmer: Confirmer
    public let eventsFileURL: URL?
    public let stdout: OutputWriter
    public let stderr: OutputWriter

    public init(
        provider: DisplayProvider,
        profileStore: ProfileStore,
        confirmer: Confirmer,
        nativeConfirmer: Confirmer,
        eventsFileURL: URL? = nil,
        stdout: OutputWriter,
        stderr: OutputWriter
    ) {
        self.provider = provider
        self.profileStore = profileStore
        self.confirmer = confirmer
        self.nativeConfirmer = nativeConfirmer
        self.eventsFileURL = eventsFileURL
        self.stdout = stdout
        self.stderr = stderr
    }
}

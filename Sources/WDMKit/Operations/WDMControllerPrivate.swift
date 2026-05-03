import WDMCore
import WDMSystem

extension WDMController {
    func mapErrors<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let error as WDMError {
            throw error
        } catch let error as ProviderError {
            throw Self.map(error)
        }
    }

    func mutate(
        _ alias: String,
        confirmer: Confirmer,
        description: String,
        apply: @escaping (UInt32) throws -> ApplyResult
    ) throws -> ApplyResult {
        try mapErrors {
            try DisplayMutator.dispatch(
                provider: provider,
                profileStore: profileStore,
                confirmer: confirmer,
                alias: alias,
                description: { _ in description },
                apply: apply
            )
        }
    }

    func safe(
        confirmer: Confirmer,
        description: String,
        apply: () throws -> ApplyResult
    ) throws -> ApplyResult {
        try SafeMutation.run(
            provider: provider,
            profileStore: profileStore,
            confirmer: confirmer,
            description: description,
            apply: apply
        )
    }

    static func map(_ error: ProviderError) -> WDMError {
        switch error {
        case .displayNotFound(let id):      return .displayNotFound(id)
        case .modeNotSupported:            return .modeNotSupported("requested mode")
        case .invalidRotation(let degrees): return .usage("invalid rotation: \(degrees)")
        case .brightnessUnsupported(let id): return .modeNotSupported("brightness unsupported on display \(id)")
        case .brightnessOutOfRange(let v): return .usage("brightness out of range (0…1): \(v)")
        case .configurationFailed(let msg): return .coreGraphicsError(msg)
        case .ioError(let msg):            return .ioError(msg)
        case .edidUnavailable(let id):     return .edidUnavailable(id)
        }
    }
}

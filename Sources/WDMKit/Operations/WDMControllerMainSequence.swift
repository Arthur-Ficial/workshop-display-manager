import WDMSystem

extension WDMController {
    public func switchMain(confirmer: Confirmer) throws -> ApplyResult {
        try mapErrors {
            let snap = try provider.snapshot()
            guard snap.displays.count >= 2, let main = snap.main else {
                throw WDMError.usage("switch requires at least two displays with a main")
            }
            guard let target = snap.displays.first(where: { $0.id != main.id && $0.isOnline }) else {
                throw WDMError.usage("no second display available to switch to")
            }
            return try setMain(target.id, confirmer: confirmer, description: "Switch main")
        }
    }

    public func cycleMain(confirmer: Confirmer) throws -> ApplyResult {
        try mapErrors {
            let snap = try provider.snapshot()
            let online = snap.displays.filter(\.isOnline)
            guard online.count >= 2, let mainIndex = online.firstIndex(where: \.isMain) else {
                throw WDMError.usage("cycle requires at least two online displays with a main")
            }
            let next = online[(mainIndex + 1) % online.count]
            return try setMain(next.id, confirmer: confirmer, description: "Cycle main")
        }
    }

    private func setMain(
        _ id: UInt32,
        confirmer: Confirmer,
        description: String
    ) throws -> ApplyResult {
        try safe(confirmer: confirmer, description: description) {
            try provider.setMain(displayID: id, options: .noConfirm)
        }
    }
}

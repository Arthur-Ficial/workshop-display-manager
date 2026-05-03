import Foundation
import WDMCore
import WDMSystem

/// Overlays user-set display aliases on top of the OS-reported names.
/// Used by `wdm list`, `wdm get`, `wdm doctor probe` so a renamed
/// display shows the user's chosen name everywhere wdm prints.
public enum DisplayAliasOverlay {
    public static func apply(
        _ displays: [DisplayInfo],
        provider: DisplayProvider,
        env: [String: String]
    ) throws -> [DisplayInfo] {
        let store = DisplayAliasStore.resolve(env: env)
        let map = (try? store.load()) ?? [:]
        if map.isEmpty { return displays }
        return displays.map { d in
            // Prefer EDID-keyed alias; fall back to id-keyed.
            let edid = try? provider.edid(for: d.id)
            let key = DisplayAliasStore.key(forID: d.id, edidStableID: edid?.stableID)
            guard let alias = map[key] else { return d }
            return DisplayInfo(
                id: d.id,
                name: alias,
                isMain: d.isMain,
                isOnline: d.isOnline,
                mirrorSource: d.mirrorSource,
                currentMode: d.currentMode,
                origin: d.origin,
                rotationDegrees: d.rotationDegrees
            )
        }
    }
}

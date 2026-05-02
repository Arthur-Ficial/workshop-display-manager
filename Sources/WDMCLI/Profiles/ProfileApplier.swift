import WDMCore
import WDMSystem

/// Applies a target Snapshot to a DisplayProvider by computing the diff against
/// the current snapshot and dispatching the minimal set of mutations.
public enum ProfileApplier {
    public static func apply(
        target: Snapshot,
        using provider: DisplayProvider,
        options: ApplyOptions
    ) throws {
        let current = try provider.snapshot()
        for desired in target.displays {
            guard let now = current.display(id: desired.id) else { continue }

            if desired.currentMode != now.currentMode {
                _ = try provider.setMode(displayID: desired.id, mode: desired.currentMode, options: options)
            }
            if desired.origin != now.origin {
                _ = try provider.move(displayID: desired.id, to: desired.origin, options: options)
            }
            if desired.rotationDegrees != now.rotationDegrees {
                _ = try provider.rotate(displayID: desired.id, degrees: desired.rotationDegrees, options: options)
            }
            switch (desired.mirrorSource, now.mirrorSource) {
            case (let want?, let have?) where want != have:
                _ = try provider.mirror(source: want, mirror: desired.id, options: options)
            case (let want?, nil):
                _ = try provider.mirror(source: want, mirror: desired.id, options: options)
            case (nil, _?):
                _ = try provider.unmirror(displayID: desired.id, options: options)
            default: break
            }
        }
        // setMain last so previous mirror/mode changes settle first.
        if let mainID = target.main?.id, current.main?.id != mainID {
            _ = try provider.setMain(displayID: mainID, options: options)
        }
    }
}

import WDMCore
import WDMSystem

extension WDMController {
    public func scaleOptions(_ alias: String) throws -> [WDMScaleOption] {
        try mapErrors {
            let display = try get(alias)
            return try uniqueScaleOptions(display: display)
        }
    }

    public func scale(
        _ alias: String,
        width: Int,
        height: Int,
        confirmer: Confirmer
    ) throws -> ApplyResult {
        try mapErrors {
            let id = try get(alias).id
            let chosen = try bestMode(displayID: id, width: width, height: height)
            return try mode(String(id), mode: chosen, confirmer: confirmer)
        }
    }

    private func uniqueScaleOptions(display: DisplayInfo) throws -> [WDMScaleOption] {
        var seen = Set<String>()
        return try provider.modes(for: display.id)
            .sorted { ($0.width, $0.height) > ($1.width, $1.height) }
            .compactMap { mode in option(mode: mode, display: display, seen: &seen) }
    }

    private func option(
        mode: Mode,
        display: DisplayInfo,
        seen: inout Set<String>
    ) -> WDMScaleOption? {
        guard seen.insert("\(mode.width)x\(mode.height)").inserted else { return nil }
        let current = display.currentMode.width == mode.width
            && display.currentMode.height == mode.height
        return WDMScaleOption(width: mode.width, height: mode.height, isCurrent: current)
    }

    private func bestMode(displayID: UInt32, width: Int, height: Int) throws -> Mode {
        let candidates = try provider.modes(for: displayID)
            .filter { $0.width == width && $0.height == height }
            .sorted { $0.refreshHz > $1.refreshHz }
        guard let chosen = candidates.first else {
            throw WDMError.modeNotSupported(
                "no mode with logical resolution \(width)x\(height) on display \(displayID)"
            )
        }
        return chosen
    }
}

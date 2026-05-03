import Foundation

/// Canonical iPhone / iPad / Android phone screen sizes for `wdm virtual create --preset`.
/// Pixel dimensions are real device pixels (the way macOS would see a
/// physical screen). Pair with `hiDPI=true` to get a Retina-scaled
/// virtual that matches the device's logical points/pixels ratio.
///
/// Order: newest first. Aliases like `iphone` / `iphone-pro` resolve to
/// the current flagship so callers can stay future-proof.
public enum MobilePresets {
    public struct Preset: Sendable, Equatable {
        public let name: String
        public let label: String
        public let width: Int
        public let height: Int
        public let refreshHz: Int
        public let hiDPI: Bool
    }

    public static let all: [Preset] = [
        // iPhone 17 family (Sept 2025 lineup) — current flagship
        .init(name: "iphone-17-pro-max", label: "iPhone 17 Pro Max",
              width: 1320, height: 2868, refreshHz: 120, hiDPI: true),
        .init(name: "iphone-17-pro",     label: "iPhone 17 Pro",
              width: 1206, height: 2622, refreshHz: 120, hiDPI: true),
        .init(name: "iphone-17-air",     label: "iPhone 17 Air",
              width: 1260, height: 2736, refreshHz: 120, hiDPI: true),
        .init(name: "iphone-17",         label: "iPhone 17",
              width: 1206, height: 2622, refreshHz: 60,  hiDPI: true),

        // iPhone 16 family (Sept 2024)
        .init(name: "iphone-16-pro-max", label: "iPhone 16 Pro Max",
              width: 1320, height: 2868, refreshHz: 120, hiDPI: true),
        .init(name: "iphone-16-pro",     label: "iPhone 16 Pro",
              width: 1206, height: 2622, refreshHz: 120, hiDPI: true),
        .init(name: "iphone-16-plus",    label: "iPhone 16 Plus",
              width: 1290, height: 2796, refreshHz: 60,  hiDPI: true),
        .init(name: "iphone-16",         label: "iPhone 16",
              width: 1179, height: 2556, refreshHz: 60,  hiDPI: true),

        // iPhone 15 family (Sept 2023) — kept for app-version compatibility tests
        .init(name: "iphone-15-pro-max", label: "iPhone 15 Pro Max",
              width: 1290, height: 2796, refreshHz: 120, hiDPI: true),
        .init(name: "iphone-15-pro",     label: "iPhone 15 Pro",
              width: 1179, height: 2556, refreshHz: 120, hiDPI: true),

        // iPhone SE
        .init(name: "iphone-se",         label: "iPhone SE (3rd gen)",
              width: 750,  height: 1334, refreshHz: 60,  hiDPI: true),

        // iPad — current generation (M5, late 2025)
        .init(name: "ipad-pro-13",       label: "iPad Pro 13\" (M5)",
              width: 2064, height: 2752, refreshHz: 120, hiDPI: true),
        .init(name: "ipad-pro-11",       label: "iPad Pro 11\" (M5)",
              width: 1668, height: 2420, refreshHz: 120, hiDPI: true),
        .init(name: "ipad-air-13",       label: "iPad Air 13\" (M3)",
              width: 2048, height: 2732, refreshHz: 60,  hiDPI: true),
        .init(name: "ipad-air",          label: "iPad Air 11\" (M3)",
              width: 1640, height: 2360, refreshHz: 60,  hiDPI: true),
        .init(name: "ipad-mini",         label: "iPad mini (A17 Pro)",
              width: 1488, height: 2266, refreshHz: 60,  hiDPI: true),

        // Android flagship comparison (early 2026)
        .init(name: "pixel-9-pro-xl",    label: "Google Pixel 9 Pro XL",
              width: 1344, height: 2992, refreshHz: 120, hiDPI: true),
        .init(name: "pixel-9-pro",       label: "Google Pixel 9 Pro",
              width: 1280, height: 2856, refreshHz: 120, hiDPI: true),
        .init(name: "galaxy-s25-ultra",  label: "Samsung Galaxy S25 Ultra",
              width: 1440, height: 3120, refreshHz: 120, hiDPI: true),
    ]

    /// Aliases that resolve to the current flagship — keeps demos / scripts
    /// working as new generations land.
    public static let aliases: [String: String] = [
        "iphone":            "iphone-17-pro-max",
        "iphone-pro":        "iphone-17-pro",
        "iphone-pro-max":    "iphone-17-pro-max",
        "ipad":              "ipad-pro-13",
        "ipad-pro":          "ipad-pro-13",
        "pixel":             "pixel-9-pro-xl",
        "galaxy":            "galaxy-s25-ultra",
    ]

    public static func find(_ name: String) -> Preset? {
        let key = name.lowercased()
        if let direct = all.first(where: { $0.name == key }) {
            return direct
        }
        if let aliasTarget = aliases[key] {
            return all.first { $0.name == aliasTarget }
        }
        return nil
    }
}

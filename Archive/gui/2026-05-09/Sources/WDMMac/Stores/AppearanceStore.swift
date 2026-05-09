import SwiftUI
import AppKit
import Combine

/// User-selectable appearance: Light, Dark, or System (default — follow
/// macOS Appearance setting). Persisted in UserDefaults so it survives
/// relaunches. HeadedRunner observes and applies to NSWindow.appearance
/// live without restarting.
public enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .system: "Default (System)"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil  // nil = inherit from system
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// Single source of truth for appearance. Views read via @ObservedObject;
/// HeadedRunner reads via Combine sink to push into NSWindow.appearance.
/// Constructed once by WDMMacAppDeps and injected — no global singleton,
/// per CLAUDE.md "no static var shared, no global state".
@MainActor
public final class AppearanceStore: ObservableObject {
    @Published public var mode: AppearanceMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.key) }
    }
    private let defaults: UserDefaults
    private static let key = "wdm.mac.appearance"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.key) ?? AppearanceMode.system.rawValue
        self.mode = AppearanceMode(rawValue: raw) ?? .system
    }
}

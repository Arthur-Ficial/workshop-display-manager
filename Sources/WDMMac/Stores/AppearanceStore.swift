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
@MainActor
public final class AppearanceStore: ObservableObject {
    @Published public var mode: AppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.key) }
    }
    public static let shared = AppearanceStore()
    private static let key = "wdm.mac.appearance"

    public init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? AppearanceMode.system.rawValue
        self.mode = AppearanceMode(rawValue: raw) ?? .system
    }
}

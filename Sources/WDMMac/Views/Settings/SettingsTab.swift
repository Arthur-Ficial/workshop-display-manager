import SwiftUI

/// Tabs in the Settings window. Add new cases here as more panes land.
/// `id` doubles as the remoteID component (settings.tab.<id>).
public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case appearance, advanced, about
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .appearance: "Appearance"
        case .advanced: "Advanced"
        case .about: "About"
        }
    }
    public var symbol: String {
        switch self {
        case .appearance: "paintpalette"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }
}

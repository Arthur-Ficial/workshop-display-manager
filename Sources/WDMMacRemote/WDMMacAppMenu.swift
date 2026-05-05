import Foundation
import AppKit

/// Minimal menu plumbing — installs the Settings… item that maps `Cmd+,`
/// to whatever target+selector the delegate provides.
@MainActor
enum WDMMacAppMenu {
    static func installSettings(target: AnyObject, action: Selector) {
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        if NSApp.mainMenu == nil { NSApp.mainMenu = mainMenu }
        let appMenuItem = mainMenu.items.first ?? {
            let m = NSMenuItem()
            m.submenu = NSMenu(title: "")
            mainMenu.addItem(m)
            return m
        }()
        let appMenu = appMenuItem.submenu ?? NSMenu()
        appMenu.addItem(.separator())
        let item = NSMenuItem(title: "Settings…", action: action, keyEquivalent: ",")
        item.target = target
        appMenu.addItem(item)
    }
}

import Foundation
import AppKit
import ApplicationServices
import WDMRemoteControl

/// Walks our OWN process's accessibility tree via the system AX framework
/// (`AXUIElementCreateApplication(getpid())` + `AXUIElementCopyAttributeValue`).
/// Going through the system AX subsystem (rather than calling
/// `accessibilityChildren()` on NSObject directly) forces SwiftUI to
/// populate the AX tree under NSHostingView — which it lazily refuses to
/// do for in-process Cocoa traversal.
///
/// This is the path that makes `wdm-mac-control click @eN` actually work
/// for every SwiftUI Button/Picker/Toggle in the app, no AppleScript bridge.
@MainActor
public final class AccessibilityWalker {
    public private(set) var refToElement: [Ref: AXUIElement] = [:]
    private var version: Int = 0
    private lazy var appElement: AXUIElement = {
        AXUIElementCreateApplication(getpid())
    }()

    public nonisolated init() {}

    public func snapshot(rootWindow: NSWindow?, interactive: Bool) -> SceneTree {
        version += 1
        refToElement.removeAll(keepingCapacity: true)
        var counter = 0
        let nodes = walk(element: appElement, counter: &counter,
                          interactive: interactive, depth: 0)
        return SceneTree(version: version, nodes: nodes)
    }

    public func dispatch(_ action: RemoteAction) -> ActionResult {
        switch action {
        case .click(let ref):
            guard let target = refToElement[ref] else {
                return .staleRef(snapshotVersion: version)
            }
            let err = AXUIElementPerformAction(target, kAXPressAction as CFString)
            if err == .success { return .ok(snapshotVersion: version) }
            return .unsupported(snapshotVersion: version,
                                reason: "AXPress failed: \(err.rawValue)")
        default:
            return .unsupported(snapshotVersion: version, reason: "M2 supports click only")
        }
    }

    private func walk(element: AXUIElement, counter: inout Int,
                      interactive: Bool, depth: Int) -> [SceneNode] {
        let id = ax_string(element, kAXIdentifierAttribute) ?? ""
        let role = ax_string(element, kAXRoleAttribute) ?? ""
        let label = ax_string(element, kAXTitleAttribute)
            ?? ax_string(element, kAXDescriptionAttribute)
        let value = ax_string(element, kAXValueAttribute)
        let isInteractive = role == "AXButton" || role == "AXRadioButton"
            || role == "AXCheckBox" || role == "AXPopUpButton"

        var children: [SceneNode] = []
        // Skip recursion into WKWebView subtrees and the wrapper
        // NSHostingView that holds them. Querying a WKWebView's
        // accessibility children involves synchronous IPC to the
        // WebContent child process; with our snapshot path being driven
        // from a `DispatchQueue.main.sync` hop on the network queue,
        // that IPC re-pumps the run loop and trips the Swift 6 actor
        // isolation runtime check, tearing the host app down. The
        // Stage's interactive elements are exposed via the
        // RemoteRegistry path instead.
        let isWebSubtree =
            role.contains("Web") ||                  // AXWebArea, etc.
            id == "stage.canvas" ||                  // our SwiftUI wrapper
            (role == "AXScrollArea" && label == nil && id.isEmpty)
        if !isWebSubtree, let kids = ax_children(element) {
            for kid in kids {
                children.append(contentsOf: walk(element: kid, counter: &counter,
                                                  interactive: interactive,
                                                  depth: depth + 1))
            }
        }

        if !id.isEmpty, !interactive || isInteractive {
            counter += 1
            let ref = Ref(index: counter)
            refToElement[ref] = element
            let bounds = ax_frame(element)
            return [SceneNode(
                ref: ref, remoteID: id, role: shortRole(role),
                label: label, value: value,
                bounds: bounds.map { NodeBounds(x: $0.origin.x, y: $0.origin.y,
                                                 w: $0.width, h: $0.height) },
                state: NodeState(enabled: true),
                children: []
            )] + children
        }
        return children
    }

    private func ax_string(_ element: AXUIElement, _ attr: String) -> String? {
        var raw: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &raw)
        guard err == .success, let value = raw else { return nil }
        if let s = value as? String { return s }
        return nil
    }

    private func ax_children(_ element: AXUIElement) -> [AXUIElement]? {
        var raw: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &raw)
        guard err == .success, let value = raw else { return nil }
        return value as? [AXUIElement]
    }

    private func ax_frame(_ element: AXUIElement) -> CGRect? {
        var posRaw: CFTypeRef?
        var sizeRaw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRaw) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRaw) == .success else {
            return nil
        }
        var pos = CGPoint.zero
        var size = CGSize.zero
        if let p = posRaw {
            // swiftlint:disable:next force_cast
            AXValueGetValue(p as! AXValue, .cgPoint, &pos)
        }
        if let s = sizeRaw {
            // swiftlint:disable:next force_cast
            AXValueGetValue(s as! AXValue, .cgSize, &size)
        }
        return CGRect(origin: pos, size: size)
    }

    private func shortRole(_ ax: String) -> String {
        switch ax {
        case "AXButton": "button"
        case "AXStaticText": "text"
        case "AXTextField": "textfield"
        case "AXPopUpButton": "popup"
        case "AXRadioButton": "radio"
        case "AXCheckBox": "checkbox"
        case "AXGroup": "group"
        case "AXImage": "image"
        case "AXScrollArea": "scroll"
        case "AXWindow": "window"
        case "AXApplication": "app"
        case "": "unknown"
        default: ax.replacingOccurrences(of: "AX", with: "").lowercased()
        }
    }
}

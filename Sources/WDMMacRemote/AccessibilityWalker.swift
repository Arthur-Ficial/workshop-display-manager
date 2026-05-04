import Foundation
import AppKit
import WDMRemoteControl

/// Walks the NSAccessibility tree of a hosted SwiftUI window and emits a
/// flat `SceneTree` of every element carrying an `.accessibilityIdentifier`.
/// SwiftUI views in NSHostingView are NOT NSView subviews — they appear
/// only via `accessibilityChildren()`, so the walker uses the AX
/// informal protocol throughout (no NSView casts).
@MainActor
public final class AccessibilityWalker {
    public private(set) var refToElement: [Ref: AnyObject] = [:]
    private var version: Int = 0

    public nonisolated init() {}

    public func snapshot(rootWindow: NSWindow?, interactive: Bool) -> SceneTree {
        version += 1
        refToElement.removeAll(keepingCapacity: true)
        guard let win = rootWindow else {
            return SceneTree(version: version, nodes: [])
        }
        var counter = 0
        // Start from the NSWindow itself — its accessibilityChildren()
        // expands into the SwiftUI tree, including proxy AX elements that
        // aren't NSView subviews.
        let nodes = walk(element: win, counter: &counter, interactive: interactive)
        if ProcessInfo.processInfo.environment["WDM_AX_DEBUG"] == "1" {
            dumpTree(element: win, depth: 0)
        }
        return SceneTree(version: version, nodes: nodes)
    }

    // KNOWN LIMITATION (M2): SwiftUI's NSHostingView only expands its
    // accessibility children when the system AX framework queries it
    // (AppleScript / VoiceOver / AccessibilityInspector). In-process
    // traversal via NSObject's accessibilityChildren() returns nil.
    //
    // Fix path: create an AXUIElement for our own pid via
    //   AXUIElementCreateApplication(getpid())
    // and walk via AXUIElementCopyAttributeValue(_, kAXChildrenAttribute, _).
    // Going through the system AX subsystem forces SwiftUI to populate.
    //
    // Tracked as Epic 17 follow-up; for M2 the registry-based path covers
    // the displays.tile.* identifiers used by the existing e2e tests.

    private func dumpTree(element: AnyObject, depth: Int) {
        let id = ax_string(element, "accessibilityIdentifier") ?? ""
        let role = ax_string(element, "accessibilityRole") ?? ""
        let label = ax_string(element, "accessibilityLabel") ?? ""
        let pad = String(repeating: "  ", count: depth)
        let cls = String(describing: type(of: element))
        FileHandle.standardError.write(Data(
            "\(pad)[\(cls)] role=\(role) id='\(id)' label='\(label)'\n".utf8))
        if depth > 20 { return }
        if let kids = ax_children(element) {
            for kid in kids { dumpTree(element: kid, depth: depth + 1) }
        }
    }

    public func dispatch(_ action: RemoteAction) -> ActionResult {
        switch action {
        case .click(let ref):
            guard let target = refToElement[ref] else {
                return .staleRef(snapshotVersion: version)
            }
            let sel = NSSelectorFromString("accessibilityPerformPress")
            if let obj = target as? NSObject, obj.responds(to: sel) {
                _ = obj.perform(sel)
                return .ok(snapshotVersion: version)
            }
            return .unsupported(snapshotVersion: version,
                                reason: "AX target does not support press")
        default:
            return .unsupported(snapshotVersion: version, reason: "M2 supports click only")
        }
    }

    private func walk(element: AnyObject, counter: inout Int, interactive: Bool) -> [SceneNode] {
        let id = ax_string(element, "accessibilityIdentifier") ?? ""
        let role = ax_string(element, "accessibilityRole") ?? ""
        let label = ax_string(element, "accessibilityLabel")
        let isInteractive = role == "AXButton" || role == "AXRadioButton"
            || role == "AXCheckBox" || role == "AXPopUpButton"

        var children: [SceneNode] = []
        if let kids = ax_children(element) {
            for kid in kids {
                children.append(contentsOf: walk(element: kid, counter: &counter,
                                                  interactive: interactive))
            }
        }

        if !id.isEmpty, !interactive || isInteractive {
            counter += 1
            let ref = Ref(index: counter)
            refToElement[ref] = element
            return [SceneNode(
                ref: ref, remoteID: id, role: shortRole(role),
                label: label,
                state: NodeState(enabled: true),
                children: []
            )] + children
        }
        return children
    }

    /// Loose @objc dispatch — works for both NSView subclasses (which
    /// implement NSAccessibility natively) and SwiftUI proxy objects
    /// (which expose AX via the informal protocol).
    private func ax_string(_ obj: AnyObject, _ method: String) -> String? {
        let sel = NSSelectorFromString(method)
        guard let nsobj = obj as? NSObject, nsobj.responds(to: sel) else { return nil }
        let result = nsobj.perform(sel)?.takeUnretainedValue()
        if let s = result as? String { return s }
        if let role = result as? NSAccessibility.Role { return role.rawValue }
        return nil
    }

    private func ax_children(_ obj: AnyObject) -> [AnyObject]? {
        let sel = NSSelectorFromString("accessibilityChildren")
        guard let nsobj = obj as? NSObject, nsobj.responds(to: sel) else { return nil }
        let result = nsobj.perform(sel)?.takeUnretainedValue()
        return result as? [AnyObject]
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
        case "": "unknown"
        default: ax.replacingOccurrences(of: "AX", with: "").lowercased()
        }
    }
}

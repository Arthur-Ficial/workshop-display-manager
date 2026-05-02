import Foundation
import AppKit
import CoreGraphics

/// PIP content view that forwards mouse / scroll / keyboard events from
/// the PIP window to the *source* display via `CGEvent`. Lets a presenter
/// click and type on a screen they aren't physically pointed at — the
/// PIP is a live mirror so they can see what they're targeting.
///
/// Coordinate translation is proportional: a click at fraction (fx, fy)
/// of the view maps to (origin.x + fx*W, origin.y + fy*H) on the source
/// display, then `CGWarpMouseCursorPosition` + `CGEventPost` deliver the
/// click. Requires Accessibility permission — same probe as `AXWindowMover`.
@MainActor
final class RemoteControlPipView: NSView {
    let sourceID: CGDirectDisplayID
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, sourceID: CGDirectDisplayID) {
        self.sourceID = sourceID
        super.init(frame: frame)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self, userInfo: nil)
        addTrackingArea(t)
        trackingArea = t
    }

    override func mouseMoved(with event: NSEvent)      { warp(event) }
    override func mouseDragged(with event: NSEvent)    { warp(event); postMouse(event, .leftMouseDragged, .left) }
    override func mouseDown(with event: NSEvent)       { warp(event); postMouse(event, .leftMouseDown,    .left) }
    override func mouseUp(with event: NSEvent)         { warp(event); postMouse(event, .leftMouseUp,      .left) }
    override func rightMouseDown(with event: NSEvent)  { warp(event); postMouse(event, .rightMouseDown,   .right) }
    override func rightMouseUp(with event: NSEvent)    { warp(event); postMouse(event, .rightMouseUp,     .right) }
    override func rightMouseDragged(with event: NSEvent) { warp(event); postMouse(event, .rightMouseDragged, .right) }
    override func scrollWheel(with event: NSEvent)     { postScroll(event) }
    override func keyDown(with event: NSEvent)         { postKey(event, true) }
    override func keyUp(with event: NSEvent)           { postKey(event, false) }
    override func flagsChanged(with event: NSEvent) {
        guard let e = CGEvent(source: nil) else { return }
        e.type = .flagsChanged
        e.flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
        e.post(tap: .cghidEventTap)
    }

    private func sourcePoint(for event: NSEvent) -> CGPoint {
        let local = convert(event.locationInWindow, from: nil)
        let b = bounds
        let nx = b.width  > 0 ? local.x / b.width  : 0
        let ny = b.height > 0 ? local.y / b.height : 0
        let src = CGDisplayBounds(sourceID)
        // NSView: y=0 is bottom. CGDisplayBounds: y=0 is top.
        return CGPoint(
            x: src.origin.x + nx * src.size.width,
            y: src.origin.y + (1 - ny) * src.size.height
        )
    }

    private func warp(_ event: NSEvent) {
        CGWarpMouseCursorPosition(sourcePoint(for: event))
    }

    private func postMouse(_ event: NSEvent, _ type: CGEventType, _ button: CGMouseButton) {
        let p = sourcePoint(for: event)
        guard let e = CGEvent(
            mouseEventSource: nil, mouseType: type,
            mouseCursorPosition: p, mouseButton: button
        ) else { return }
        e.flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
        if button == .left {
            e.setIntegerValueField(.mouseEventClickState, value: Int64(event.clickCount))
        }
        e.post(tap: .cghidEventTap)
    }

    private func postScroll(_ event: NSEvent) {
        let dy = Int32(event.scrollingDeltaY)
        let dx = Int32(event.scrollingDeltaX)
        guard let e = CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel,
            wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0
        ) else { return }
        e.post(tap: .cghidEventTap)
    }

    private func postKey(_ event: NSEvent, _ keyDown: Bool) {
        guard let e = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(event.keyCode),
            keyDown: keyDown
        ) else { return }
        e.flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
        e.post(tap: .cghidEventTap)
    }
}

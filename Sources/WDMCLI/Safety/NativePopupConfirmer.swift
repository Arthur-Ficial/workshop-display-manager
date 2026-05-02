import Foundation
import AppKit

/// Native macOS HUD-style confirmation overlay. Activated by `--confirm`.
///
/// Modeled on the system volume / brightness HUD: borderless `NSPanel` with
/// `.hudWindow` style and `NSVisualEffectView` (.hudWindow material,
/// .behindWindow blending), no title bar, no traffic-light buttons, compact,
/// shown at the lower third of the screen the cursor is on. Content is a
/// large monospaced countdown, a thin progress bar that drains over the
/// timeout, and a one-line hint with the keyboard shortcuts.
///
/// Behaviour:
///   - SPACE → keep (returns true).
///   - Any other key → cancel/revert.
///   - Timeout → cancel/revert.
///
/// `NSGlassEffectView` is intentionally avoided — it has known issues on
/// macOS Tahoe that produce blank or wrongly-tinted overlays for unbundled
/// CLI tools.
public final class NativePopupConfirmer: Confirmer, @unchecked Sendable {
    public init() {}

    public func confirm(message: String, timeoutSeconds: Int) -> Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                self.runOnMain(message: message, timeout: timeoutSeconds)
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                self.runOnMain(message: message, timeout: timeoutSeconds)
            }
        }
    }

    @MainActor
    private func runOnMain(message: String, timeout: Int) -> Bool {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let panel = HUDPanel.make()
        let bounds = panel.contentView!.bounds
        let content = HUDContent(frame: bounds, total: timeout, message: message)
        content.autoresizingMask = [.width, .height]
        panel.installContent(content)

        Self.placeOnCursorScreen(panel)
        panel.orderFrontRegardless()

        defer {
            panel.orderOut(nil)
            panel.close()
        }

        // Global key tap so SPACE/ESC are caught even though `.accessory` +
        // `.nonactivatingPanel` mean we never own the keyboard focus.
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let kc = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let box = Unmanaged<KeyBox>.fromOpaque(refcon).takeUnretainedValue()
                box.set(kc)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(KeyBoxStash.shared.box).toOpaque()
        )
        let runLoopSource = tap.flatMap { CFMachPortCreateRunLoopSource(nil, $0, 0) }
        if let s = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), s, .commonModes)
        }
        if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
        defer {
            if let s = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), s, .commonModes)
            }
            KeyBoxStash.shared.box.clear()
        }

        // Smooth bar drain across the full timeout.
        content.beginBarAnimation(duration: TimeInterval(timeout))

        let start = Date()
        var lastShown = -1
        while true {
            let elapsed = Int(Date().timeIntervalSince(start))
            let remaining = timeout - elapsed
            if remaining <= 0 { return false }
            if remaining != lastShown {
                lastShown = remaining
                content.updateNumber(remaining)
            }
            let until = Date().addingTimeInterval(0.05)
            while let event = app.nextEvent(matching: .any, until: until, inMode: .default, dequeue: true) {
                if event.type == .keyDown {
                    return event.keyCode == 49   // 49 = space
                }
                app.sendEvent(event)
            }
            if let kc = KeyBoxStash.shared.box.takeIfChanged() {
                return kc == 49
            }
        }
    }

    @MainActor
    private static func placeOnCursorScreen(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let s = screen else { window.center(); return }
        let f = window.frame
        let x = s.frame.midX - f.width / 2
        let y = s.frame.midY - f.height / 2
        window.setFrame(NSRect(x: x, y: y, width: f.width, height: f.height), display: true)
    }
}

// MARK: - Panel

@MainActor
final class HUDPanel: NSPanel {
    static func make() -> HUDPanel {
        let frame = NSRect(x: 0, y: 0, width: 420, height: 180)
        let p = HUDPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.becomesKeyOnlyIfNeeded = true
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.animationBehavior = .utilityWindow

        let bg = NSVisualEffectView(frame: frame)
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 16
        bg.layer?.cornerCurve = .continuous
        bg.layer?.masksToBounds = true
        bg.autoresizingMask = [.width, .height]
        p.contentView = bg
        return p
    }

    func installContent(_ content: NSView) {
        contentView?.addSubview(content)
    }
}

// MARK: - Content

@MainActor
final class HUDContent: NSView {
    private let title = NSTextField(labelWithString: "")
    private let status = NSTextField(labelWithString: "")
    private let bar = ProgressBar()
    private let hint = NSTextField(labelWithString: "")
    private var lastSeconds = -1

    init(frame: NSRect, total: Int, message: String) {
        super.init(frame: frame)
        wantsLayer = true

        title.stringValue = message.isEmpty ? "Display change applied" : message
        title.alignment = .center
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .labelColor
        title.maximumNumberOfLines = 2
        title.lineBreakMode = .byTruncatingTail
        addSubview(title)

        status.stringValue = "Reverting in \(total)s…"
        status.alignment = .center
        status.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        status.textColor = .labelColor
        addSubview(status)

        addSubview(bar)

        hint.stringValue = "Press SPACE to keep   ·   any other key reverts"
        hint.alignment = .center
        hint.font = .systemFont(ofSize: 11, weight: .regular)
        hint.textColor = .secondaryLabelColor
        addSubview(hint)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        let w = bounds.width
        title.frame  = NSRect(x: 16, y: bounds.height - 50, width: w - 32, height: 36)
        status.frame = NSRect(x: 16, y: 78, width: w - 32, height: 18)
        bar.frame    = NSRect(x: 28, y: 64, width: w - 56, height: 4)
        hint.frame   = NSRect(x: 16, y: 22, width: w - 32, height: 16)
    }

    func updateNumber(_ remaining: Int) {
        if remaining == lastSeconds { return }
        lastSeconds = remaining
        status.stringValue = "Reverting in \(remaining)s…"
    }

    func beginBarAnimation(duration: TimeInterval) {
        bar.animate(toProgress: 0.0, duration: duration)
    }
}

// MARK: - Thin progress bar (volume-HUD style)

@MainActor
final class ProgressBar: NSView {
    private let track = CAShapeLayer()
    private let fill = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(track)
        layer?.addSublayer(fill)
        configureLayers()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        configureLayers()
    }

    private func configureLayers() {
        let radius = bounds.height / 2
        let rect = bounds
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        track.frame = bounds
        track.path = path
        track.fillColor = NSColor.white.withAlphaComponent(0.12).cgColor

        fill.frame = bounds
        fill.path = path
        fill.fillColor = NSColor.labelColor.cgColor
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: 0, y: bounds.midY)
        fill.bounds = bounds
        fill.transform = CATransform3DMakeScale(1.0, 1.0, 1.0)
    }

    /// Animates the fill horizontally from full → `target` proportion.
    func animate(toProgress target: CGFloat, duration: TimeInterval) {
        let anim = CABasicAnimation(keyPath: "transform.scale.x")
        anim.fromValue = 1.0
        anim.toValue = target
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        fill.add(anim, forKey: "drain")
    }
}

// MARK: - Global key tap plumbing

/// Tiny mailbox that the C event-tap callback can write into safely.
final class KeyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var key: UInt16? = nil
    func set(_ k: UInt16) { lock.withLock { key = k } }
    func takeIfChanged() -> UInt16? {
        lock.withLock {
            let v = key
            key = nil
            return v
        }
    }
    func clear() { lock.withLock { key = nil } }
}

enum KeyBoxStash {
    static let shared = Singleton()
    final class Singleton: @unchecked Sendable {
        let box = KeyBox()
    }
}

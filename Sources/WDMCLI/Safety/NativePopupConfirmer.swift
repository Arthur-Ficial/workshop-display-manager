import Foundation
import AppKit

/// Mac-native confirmation popup with a live countdown. Activated by `--confirm`.
///
/// Frosted-glass NSPanel (NSVisualEffectView, hudWindow material), borderless
/// with a soft white inner stroke, large circular countdown ring, prominent
/// SPACE keycap cue. Briefly raises activation policy to `.regular` so the
/// panel reliably grabs keyboard focus, then restores prior policy on dismiss.
public final class NativePopupConfirmer: Confirmer, @unchecked Sendable {
    public init() {}

    public func confirm(timeoutSeconds: Int) -> Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { self.runOnMain(timeout: timeoutSeconds) }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { self.runOnMain(timeout: timeoutSeconds) }
        }
    }

    @MainActor
    private func runOnMain(timeout: Int) -> Bool {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let window = ConfirmPanel.make()
        let view = ConfirmView(frame: window.contentView!.bounds, total: timeout)
        view.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(view)

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        app.activate(ignoringOtherApps: true)
        window.makeKey()

        defer {
            window.orderOut(nil)
            window.close()
        }

        // A CGEventTap-based global key catcher works even when our process
        // is `.accessory` and does not own the keyboard focus. We tear it
        // down on dismiss.
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

        let start = Date()
        var lastShown = -1
        while true {
            let elapsed = Int(Date().timeIntervalSince(start))
            let remaining = timeout - elapsed
            if remaining <= 0 { return false }
            if remaining != lastShown {
                lastShown = remaining
                view.update(remaining: remaining, total: timeout)
            }

            // Drain a tick of AppKit events so the window draws + animates.
            let until = Date().addingTimeInterval(0.05)
            while let event = app.nextEvent(matching: .any, until: until, inMode: .default, dequeue: true) {
                if event.type == .keyDown {
                    return event.keyCode == 49
                }
                app.sendEvent(event)
            }
            // Then check the global tap.
            if let kc = KeyBoxStash.shared.box.takeIfChanged() {
                return kc == 49
            }
        }
    }
}

// MARK: - Global key tap plumbing

/// Tiny mailbox that the C event-tap callback can write into safely.
final class KeyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var key: UInt16? = nil
    var lastKey: UInt16 = 0xFFFF
    func set(_ k: UInt16) {
        lock.withLock { key = k; lastKey = k }
    }
    func takeIfChanged() -> UInt16? {
        lock.withLock {
            let v = key
            key = nil
            return v
        }
    }
    func clear() {
        lock.withLock { key = nil; lastKey = 0xFFFF }
    }
}

enum KeyBoxStash {
    static let shared = Singleton()
    final class Singleton: @unchecked Sendable {
        let box = KeyBox()
    }
}

// MARK: - Panel

@MainActor
final class ConfirmPanel: NSPanel {
    static func make() -> ConfirmPanel {
        let frame = NSRect(x: 0, y: 0, width: 620, height: 360)
        let panel = ConfirmPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let blur = NSVisualEffectView(frame: frame)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 28
        blur.layer?.cornerCurve = .continuous
        blur.layer?.masksToBounds = true
        blur.layer?.borderWidth = 1
        blur.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        blur.autoresizingMask = [.width, .height]

        // Inner highlight — a 1px white stroke just inside the rounded edge,
        // emphasising the "glass" feel the way native HUDs do.
        let highlight = CALayer()
        highlight.frame = blur.bounds.insetBy(dx: 1, dy: 1)
        highlight.cornerRadius = 27
        highlight.cornerCurve = .continuous
        highlight.borderWidth = 0.5
        highlight.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        highlight.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        blur.layer?.addSublayer(highlight)

        panel.contentView = blur
        return panel
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - Content view

@MainActor
final class ConfirmView: NSView {
    private let title = NSTextField(labelWithString: "")
    private let countdown = NSTextField(labelWithString: "")
    private let progress = ProgressRing()
    private let spaceCap = KeyCapView(label: "space")
    private let spaceText = NSTextField(labelWithString: "")
    private let separator = NSTextField(labelWithString: "·")
    private let cancelText = NSTextField(labelWithString: "")

    init(frame: NSRect, total: Int) {
        super.init(frame: frame)
        wantsLayer = true

        title.stringValue = "Keep this display change?"
        title.alignment = .center
        title.font = roundedFont(size: 26, weight: .semibold)
        title.textColor = NSColor.labelColor
        addSubview(title)

        countdown.stringValue = "\(total)"
        countdown.alignment = .center
        countdown.font = .monospacedDigitSystemFont(ofSize: 72, weight: .bold)
        countdown.textColor = NSColor.labelColor
        addSubview(countdown)

        addSubview(progress)

        addSubview(spaceCap)
        spaceText.stringValue = "to keep"
        spaceText.font = roundedFont(size: 14, weight: .medium)
        spaceText.textColor = NSColor.secondaryLabelColor
        addSubview(spaceText)

        separator.font = .systemFont(ofSize: 14, weight: .regular)
        separator.textColor = NSColor.tertiaryLabelColor
        addSubview(separator)

        cancelText.stringValue = "any other key cancels"
        cancelText.font = roundedFont(size: 14, weight: .medium)
        cancelText.textColor = NSColor.secondaryLabelColor
        addSubview(cancelText)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        if let desc = base.fontDescriptor.withDesign(.rounded) {
            return NSFont(descriptor: desc, size: size) ?? base
        }
        return base
    }

    override func layout() {
        super.layout()
        let w = bounds.width

        title.frame = NSRect(x: 0, y: bounds.height - 64, width: w, height: 30)

        let ringSize: CGFloat = 170
        let ringY: CGFloat = 96
        progress.frame  = NSRect(x: (w - ringSize) / 2, y: ringY,
                                 width: ringSize, height: ringSize)
        countdown.frame = NSRect(x: (w - ringSize) / 2,
                                 y: ringY + (ringSize - 80) / 2,
                                 width: ringSize, height: 80)

        // Bottom row: [SPACE] to keep   ·   any other key cancels
        let capW: CGFloat = 80, capH: CGFloat = 30
        let toKeepW: CGFloat = 70
        let dotW: CGFloat = 18
        let cancelW: CGFloat = 200
        let gap: CGFloat = 10
        let totalW = capW + gap + toKeepW + gap + dotW + gap + cancelW
        let baseX = (w - totalW) / 2
        let rowY: CGFloat = 36

        spaceCap.frame   = NSRect(x: baseX,                                 y: rowY - 4, width: capW, height: capH)
        spaceText.frame  = NSRect(x: baseX + capW + gap,                    y: rowY,     width: toKeepW, height: 22)
        separator.frame  = NSRect(x: baseX + capW + gap + toKeepW + gap,    y: rowY,     width: dotW, height: 22)
        cancelText.frame = NSRect(x: baseX + capW + gap + toKeepW + gap + dotW + gap,
                                  y: rowY, width: cancelW, height: 22)
    }

    func update(remaining: Int, total: Int) {
        countdown.stringValue = "\(remaining)"
        progress.progress = Double(remaining) / Double(max(1, total))
        progress.needsDisplay = true
    }
}

// MARK: - SPACE key cap

@MainActor
final class KeyCapView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(label text: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.white.withAlphaComponent(0.30).cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor

        label.stringValue = text
        label.alignment = .center
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor.labelColor
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 8, dy: 4)
    }
}

// MARK: - Progress ring

@MainActor
final class ProgressRing: NSView {
    var progress: Double = 1.0   // 1.0 → full ring, 0.0 → empty

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let lineWidth: CGFloat = 8
        let r = min(bounds.width, bounds.height) / 2 - lineWidth
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        // Track
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addArc(center: center, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        // Active arc — drawn from top, clockwise
        let start = CGFloat.pi / 2
        let end = start - CGFloat(progress) * .pi * 2
        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.addArc(center: center, radius: r, startAngle: start, endAngle: end, clockwise: true)
        ctx.strokePath()
    }
}

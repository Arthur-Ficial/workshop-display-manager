import Foundation
import AppKit

/// Mac-native confirmation popup with a live countdown. Activated by `--confirm`.
///
/// On macOS 26 (Tahoe) the background uses **Liquid Glass** via
/// `NSGlassEffectView`. Earlier macOS versions fall back to `NSVisualEffectView`
/// with hudWindow material. Window has transparent title bar with the standard
/// traffic-light buttons (close/minimise/zoom). The countdown ring animates
/// smoothly via Core Animation; the number updates once per second.
///
/// Behaviour:
///   - SPACE key → keep the change (returns true).
///   - Any other key → cancel/revert.
///   - Close button (red traffic light) → cancel/revert.
///   - Timeout reaching 0 → cancel/revert.
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

        let window = ConfirmWindow.make()
        let bounds = window.contentView!.bounds
        let content = ConfirmView(frame: bounds, total: timeout)
        content.autoresizingMask = [.width, .height]
        window.installContent(content)

        let closeFlag = CloseFlag()
        let delegate = ConfirmWindowDelegate(flag: closeFlag)
        window.delegate = delegate

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        app.activate(ignoringOtherApps: true)
        window.makeKey()

        defer {
            window.delegate = nil
            window.orderOut(nil)
            window.close()
        }

        // Global key tap so SPACE/etc. are caught even when our process
        // is `.accessory` and does not own the keyboard focus.
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

        // Kick off the smooth ring animation: shrink from full → empty across timeout.
        content.beginRingAnimation(duration: TimeInterval(timeout))

        let start = Date()
        var lastShown = -1
        while !closeFlag.isClosed {
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
                    return event.keyCode == 49
                }
                app.sendEvent(event)
            }
            if let kc = KeyBoxStash.shared.box.takeIfChanged() {
                return kc == 49
            }
        }
        // Window was closed by the user (red traffic light) → revert.
        return false
    }
}

// MARK: - Window

@MainActor
final class ConfirmWindow: NSPanel {
    private var glass: NSView?

    static func make() -> ConfirmWindow {
        let frame = NSRect(x: 0, y: 0, width: 640, height: 420)
        let w = ConfirmWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        w.title = "wdm"
        w.titleVisibility = .visible
        w.titlebarAppearsTransparent = true
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .popUpMenu
        w.isMovableByWindowBackground = true
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Force standard traffic lights to render — NSPanel hides them by
        // default. We explicitly unhide each so the user sees the familiar
        // close / minimise / zoom dots and can dismiss with the close button.
        w.standardWindowButton(.closeButton)?.isHidden = false
        w.standardWindowButton(.miniaturizeButton)?.isHidden = false
        w.standardWindowButton(.zoomButton)?.isHidden = false
        // Keep zoom enabled but disable the resize edge to keep our layout stable.
        w.styleMask.remove(.resizable)
        w.installGlass()
        return w
    }

    private func installGlass() {
        let bounds = contentView!.bounds
        let glass: NSView
        if #available(macOS 26.0, *) {
            let g = NSGlassEffectView(frame: bounds)
            g.cornerRadius = 22
            glass = g
        } else {
            let v = NSVisualEffectView(frame: bounds)
            v.material = .hudWindow
            v.blendingMode = .behindWindow
            v.state = .active
            v.wantsLayer = true
            v.layer?.cornerRadius = 22
            v.layer?.cornerCurve = .continuous
            v.layer?.masksToBounds = true
            v.layer?.borderWidth = 0.5
            v.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
            glass = v
        }
        glass.autoresizingMask = [.width, .height]
        contentView = glass
        self.glass = glass
    }

    /// Place the content view inside whichever glass container is active.
    func installContent(_ content: NSView) {
        guard let host = glass else { return }
        if #available(macOS 26.0, *), let glassHost = host as? NSGlassEffectView {
            glassHost.contentView = content
        } else {
            host.addSubview(content)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

@MainActor
final class ConfirmWindowDelegate: NSObject, NSWindowDelegate {
    let flag: CloseFlag
    init(flag: CloseFlag) { self.flag = flag }
    func windowWillClose(_ notification: Notification) { flag.isClosed = true }
}

final class CloseFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var closed = false
    var isClosed: Bool {
        get { lock.withLock { closed } }
        set { lock.withLock { closed = newValue } }
    }
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
        title.textColor = .labelColor
        addSubview(title)

        countdown.stringValue = "\(total)"
        countdown.alignment = .center
        countdown.font = .monospacedDigitSystemFont(ofSize: 80, weight: .bold)
        countdown.textColor = .labelColor
        addSubview(countdown)

        addSubview(progress)

        addSubview(spaceCap)
        spaceText.stringValue = "to keep"
        spaceText.font = roundedFont(size: 14, weight: .medium)
        spaceText.textColor = .secondaryLabelColor
        addSubview(spaceText)

        separator.font = .systemFont(ofSize: 14, weight: .regular)
        separator.textColor = .tertiaryLabelColor
        addSubview(separator)

        cancelText.stringValue = "any other key cancels"
        cancelText.font = roundedFont(size: 14, weight: .medium)
        cancelText.textColor = .secondaryLabelColor
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

        title.frame = NSRect(x: 0, y: bounds.height - 80, width: w, height: 32)

        let ringSize: CGFloat = 190
        let ringY: CGFloat = 100
        progress.frame  = NSRect(x: (w - ringSize) / 2, y: ringY,
                                 width: ringSize, height: ringSize)
        countdown.frame = NSRect(x: (w - ringSize) / 2,
                                 y: ringY + (ringSize - 90) / 2,
                                 width: ringSize, height: 90)

        // Bottom row: [SPACE] to keep · any other key cancels
        let capW: CGFloat = 78, capH: CGFloat = 28
        let toKeepW: CGFloat = 70
        let dotW: CGFloat = 14
        let cancelW: CGFloat = 200
        let gap: CGFloat = 10
        let totalW = capW + gap + toKeepW + gap + dotW + gap + cancelW
        let baseX = (w - totalW) / 2
        let rowY: CGFloat = 38

        spaceCap.frame   = NSRect(x: baseX,                                 y: rowY - 4, width: capW, height: capH)
        spaceText.frame  = NSRect(x: baseX + capW + gap,                    y: rowY,     width: toKeepW, height: 22)
        separator.frame  = NSRect(x: baseX + capW + gap + toKeepW + gap,    y: rowY,     width: dotW, height: 22)
        cancelText.frame = NSRect(x: baseX + capW + gap + toKeepW + gap + dotW + gap,
                                  y: rowY, width: cancelW, height: 22)
    }

    func updateNumber(_ remaining: Int) {
        // Cross-fade the digit change for a less jarring update.
        countdown.layer?.removeAllAnimations()
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.4
        fade.toValue = 1.0
        fade.duration = 0.2
        countdown.layer?.add(fade, forKey: "fade")
        countdown.stringValue = "\(remaining)"
    }

    func beginRingAnimation(duration: TimeInterval) {
        progress.animate(toProgress: 0.0, duration: duration)
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
        label.textColor = .labelColor
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 8, dy: 4)
    }
}

// MARK: - Progress ring (CAShapeLayer-based, smoothly animated)

@MainActor
final class ProgressRing: NSView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(progressLayer)
        configureLayers()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        configureLayers()
    }

    private func configureLayers() {
        let lineWidth: CGFloat = 9
        let inset = lineWidth / 2 + 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = CGPath(ellipseIn: rect, transform: nil)

        trackLayer.frame = bounds
        trackLayer.path = path
        trackLayer.fillColor = NSColor.clear.cgColor
        trackLayer.strokeColor = NSColor.white.withAlphaComponent(0.10).cgColor
        trackLayer.lineWidth = lineWidth

        progressLayer.frame = bounds
        progressLayer.path = path
        progressLayer.fillColor = NSColor.clear.cgColor
        progressLayer.strokeColor = NSColor.controlAccentColor.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 1.0
        // Rotate 90° counter-clockwise so the stroke starts at 12 o'clock and
        // shrinks clockwise, matching native countdown UI.
        progressLayer.transform = CATransform3DMakeRotation(-.pi / 2, 0, 0, 1)
        progressLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        progressLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        progressLayer.bounds = bounds
    }

    func animate(toProgress target: CGFloat, duration: TimeInterval) {
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = progressLayer.strokeEnd
        anim.toValue = target
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        progressLayer.add(anim, forKey: "shrink")
        progressLayer.strokeEnd = target
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

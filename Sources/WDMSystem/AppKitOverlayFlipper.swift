import Foundation
import AppKit
import CoreGraphics
import CoreImage
import CoreMedia
@preconcurrency import ScreenCaptureKit
import WDMCore

/// Real overlay flipper. Opens a borderless `NSWindow` covering the target
/// display, captures that display via `SCStream` (excluding the overlay
/// window itself to avoid a feedback loop), and renders each frame into a
/// flipping `CALayer`. No private APIs — works on every Mac including
/// Apple Silicon, AirPlay, and Sidecar — at the cost of holding a foreground
/// process for the duration of use.
///
/// Requires Screen Recording permission. The first time this runs, macOS
/// prompts the user; if denied, `SCShareableContent.current` throws.
public final class AppKitOverlayFlipper: OverlayFlipper, @unchecked Sendable {

    private let lock = NSLock()
    private var stopRequested = false
    nonisolated(unsafe) private var stream: SCStream?
    nonisolated(unsafe) private var window: NSWindow?
    nonisolated(unsafe) private var frameSink: NSObject?
    nonisolated(unsafe) private var cursorHiddenOnDisplay: CGDirectDisplayID?
    nonisolated(unsafe) private var signalSources: [DispatchSourceSignal] = []
    /// Activation policy at the moment we entered run() — restored in
    /// teardown(). For a GUI app (wdm-mac), this is .regular; switching
    /// to .accessory and never restoring would hide the Dock icon and
    /// main menu permanently after one flip.
    nonisolated(unsafe) private var savedActivationPolicy: NSApplication.ActivationPolicy?

    public init() {}

    public func run(displayID: UInt32, flip: Flip, durationMs: Int?) throws {
        // Defensive: if a previous flip left a window or stream behind
        // (e.g. caller killed before teardown ran), kill them now so
        // a new flip never doubles up onto a stale overlay.
        teardown()
        try PermissionProbe.requireScreenRecording(context: "flip-overlay")
        // Reset the stop flag from any previous run.
        lock.withLock { stopRequested = false }
        // Only switch to .accessory when the host is .prohibited
        // (a bare CLI process — we want to suppress the Dock icon
        // flash during flip). For .regular hosts (GUI apps like
        // wdm-mac), switching would HIDE the user's main window and
        // dock icon — looks like a crash to the user even though we
        // restore the policy in teardown. Per the user's "looks like
        // a crash" report 2026-05-05.
        let current = readActivationPolicy()
        if current == .prohibited {
            savedActivationPolicy = current
            runOnMainSetActivationPolicy(.accessory)
        } else {
            savedActivationPolicy = nil
        }
        installSignalHandlers()

        let errBox = ErrorBox()
        let started = DispatchSemaphore(value: 0)
        Task { @MainActor in
            do {
                try await self.startStream(displayID: displayID, flip: flip)
            } catch {
                errBox.set(error)
            }
            started.signal()
        }

        // Drive the main run-loop while waiting for the async start to complete.
        let startDeadline = Date(timeIntervalSinceNow: 5.0)
        while started.wait(timeout: .now() + .milliseconds(50)) == .timedOut {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            if Date() > startDeadline { break }
        }
        if let err = errBox.get() {
            // If startStream failed, tear down anything we put up
            // before it threw — never leave an orphan overlay window.
            teardown()
            throw err
        }

        if let ms = durationMs {
            let deadline = Date(timeIntervalSinceNow: TimeInterval(ms) / 1000.0)
            while Date() < deadline && !flagged() {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            }
        } else {
            while !flagged() {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
            }
        }
        teardown()
    }

    private func runOnMainSetActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                _ = NSApplication.shared.setActivationPolicy(policy)
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    _ = NSApplication.shared.setActivationPolicy(policy)
                }
            }
        }
    }

    private func installSignalHandlers() {
        // Translate SIGINT / SIGTERM / SIGHUP into stop() so teardown runs and
        // the cursor is unhidden — otherwise CGDisplayHideCursor stays in effect
        // across this process's death.
        // Order matters: SIG_IGN the default action *first* (so the kernel
        // doesn't kill us), then start the dispatch sources. Sources must be
        // retained on the instance — local-var sources get deallocated when
        // this function returns and never fire.
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        signal(SIGHUP, SIG_IGN)
        let signals: [Int32] = [SIGINT, SIGTERM, SIGHUP]
        for sig in signals {
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in self?.stop() }
            src.resume()
            signalSources.append(src)
        }
    }

    public func stop() { lock.withLock { stopRequested = true } }

    // MARK: - private

    private func flagged() -> Bool { lock.withLock { stopRequested } }

    @MainActor
    private func startStream(displayID: UInt32, flip: Flip) async throws {
        let content = try await SCShareableContent.current
        guard let scDisplay = content.displays.first(where: { $0.displayID == CGDirectDisplayID(displayID) }) else {
            throw ProviderError.displayNotFound(displayID)
        }

        // NSWindow.contentRect uses screen coordinates (bottom-left origin),
        // not CGDisplayBounds (top-left). Find the matching NSScreen and use
        // its frame directly so the overlay actually covers the target display.
        guard let nsScreen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
                == scDisplay.displayID
        }) else {
            throw ProviderError.displayNotFound(displayID)
        }
        let frame = nsScreen.frame

        let win = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
        // Transparent until the first captured frame arrives. Earlier
        // versions used .black + isOpaque=true which caused a visible
        // black flash before the first frame, and a permanently-black
        // overlay if the stream ever failed to deliver frames (the
        // process would leave a black window over the screen).
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        let view = NSView(frame: win.contentView!.bounds)
        view.wantsLayer = true
        view.layerContentsRedrawPolicy = .duringViewResize
        let imageLayer = CALayer()
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.frame = view.bounds
        imageLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        imageLayer.setAffineTransform(transform(for: flip))
        view.layer?.addSublayer(imageLayer)
        let layer = imageLayer
        win.contentView = view
        win.orderFrontRegardless()
        self.window = win

        // Re-fetch shareable content so our just-opened window appears in
        // `content.windows`, then exclude it from the capture to avoid
        // a recursive screen-of-screen feedback loop.
        let updated = try await SCShareableContent.current
        let ourCGID = CGWindowID(win.windowNumber)
        let excluded = updated.windows.filter { $0.windowID == ourCGID }

        // Capture at NATIVE pixel resolution, not logical points. On a
        // Retina display SCDisplay.width/height return logical points;
        // capturing at points yields a blurry upscaled overlay because
        // the layer renders into a window at 2x. Multiply by the
        // backing scale factor so we capture every pixel the display
        // actually shows, then mark the layer's contentsScale so
        // CoreAnimation knows the image is hi-DPI.
        let scale = nsScreen.backingScaleFactor
        let cfg = SCStreamConfiguration()
        cfg.width  = Int(CGFloat(scDisplay.width)  * scale)
        cfg.height = Int(CGFloat(scDisplay.height) * scale)
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        cfg.queueDepth = 5
        cfg.showsCursor = true
        cfg.colorSpaceName = CGColorSpace.sRGB
        cfg.scalesToFit = false
        layer.contentsScale = scale
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .nearest
        let filter = SCContentFilter(display: scDisplay, excludingWindows: excluded)

        let output = FrameSink(layer: layer)
        let captureQ = DispatchQueue(label: "wdm.overlay.capture", qos: .userInteractive)
        let s = SCStream(filter: filter, configuration: cfg, delegate: nil)
        try s.addStreamOutput(output, type: .screen, sampleHandlerQueue: captureQ)
        try await s.startCapture()
        self.stream = s
        self.frameSink = output

        // Hide the live cursor while it's over the target display so only
        // the captured (flipped) cursor is visible. Reference-counted —
        // matched by CGDisplayShowCursor in teardown(). If the process is
        // killed -9, the cursor stays hidden until next reboot or another
        // process calls CGDisplayShowCursor.
        CGDisplayHideCursor(scDisplay.displayID)
        self.cursorHiddenOnDisplay = scDisplay.displayID
    }

    private func teardown() {
        if let id = cursorHiddenOnDisplay {
            CGDisplayShowCursor(id)
            cursorHiddenOnDisplay = nil
        }
        // Detach the frame sink's layer reference FIRST so any
        // in-flight frame callbacks become no-ops, then synchronously
        // wait for SCStream to stop. Closing the window before the
        // stream is stopped + frames are flushed crashes AppKit when
        // a late frame writes to the now-deallocated NSView layer
        // (user-reported "app crashes after Flip" 2026-05-05).
        (frameSink as? FrameSink)?.detachLayer()
        if let s = stream {
            let done = DispatchSemaphore(value: 0)
            Task {
                try? await s.stopCapture()
                done.signal()
            }
            _ = done.wait(timeout: .now() + .milliseconds(500))
        }
        stream = nil
        frameSink = nil
        // Synchronous window close: a previous async dispatch let the
        // overlay linger a beat past teardown which on a slow main
        // thread looked like an "orphan black screen". Closing on the
        // current thread (we're already on main when teardown runs in
        // the GUI path) tears it down immediately.
        let toClose = window
        window = nil
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                toClose?.orderOut(nil)
                toClose?.close()
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    toClose?.orderOut(nil)
                    toClose?.close()
                }
            }
        }
        // Restore the calling app's activation policy. Without this,
        // a GUI host (wdm-mac) loses its Dock icon and main menu
        // permanently after one flip — `runOnMainSetActivationPolicy(.accessory)`
        // is a one-way switch otherwise.
        if let saved = savedActivationPolicy {
            runOnMainSetActivationPolicy(saved)
            savedActivationPolicy = nil
        }
    }

    private func readActivationPolicy() -> NSApplication.ActivationPolicy {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { NSApplication.shared.activationPolicy() }
        }
        var policy: NSApplication.ActivationPolicy = .regular
        DispatchQueue.main.sync {
            MainActor.assumeIsolated { policy = NSApplication.shared.activationPolicy() }
        }
        return policy
    }

    private func transform(for flip: Flip) -> CGAffineTransform {
        switch flip {
        case .none:       return .identity
        case .horizontal: return CGAffineTransform(scaleX: -1, y: 1)
        case .vertical:   return CGAffineTransform(scaleX: 1, y: -1)
        case .both:       return CGAffineTransform(scaleX: -1, y: -1)
        }
    }
}

private final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var err: Error?
    func set(_ e: Error) { lock.withLock { err = e } }
    func get() -> Error? { lock.withLock { err } }
}

@objc private final class FrameSink: NSObject, SCStreamOutput, @unchecked Sendable {
    nonisolated(unsafe) private var _layer: CALayer?
    private let lock = NSLock()
    init(layer: CALayer) { self._layer = layer }
    /// Called from teardown to break the layer reference. Without this,
    /// late-arriving SCStream frames could write to a layer whose
    /// owning NSWindow had already closed → AppKit crash.
    func detachLayer() { lock.withLock { _layer = nil } }
    @objc func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let layer = lock.withLock { _layer }
        guard let layer else { return }
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return }
        DispatchQueue.main.async { [weak self] in
            // Re-check on main — teardown may have detached between
            // bg-thread render and main-thread commit.
            guard let live = self?.lock.withLock({ self?._layer }), live === layer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.contents = cg
            CATransaction.commit()
        }
    }
}

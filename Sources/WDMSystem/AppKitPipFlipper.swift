import Foundation
import AppKit
import CoreGraphics
import CoreImage
import CoreMedia
import ImageIO
import ScreenCaptureKit
import WDMCore

/// Real PIP flipper. Captures `sourceID` via `SCStream` and renders frames
/// into a movable / resizable `NSWindow` placed on `destinationID`. The
/// window has a normal title bar so the user can drag it across displays
/// or close it; teardown unwinds capture + signal handlers cleanly.
public final class AppKitPipFlipper: PipFlipper, @unchecked Sendable {

    private let lock = NSLock()
    private var stopRequested = false
    nonisolated(unsafe) private var stream: SCStream?
    nonisolated(unsafe) private var window: NSWindow?
    nonisolated(unsafe) private var frameSink: NSObject?
    nonisolated(unsafe) private var captureTimer: DispatchSourceTimer?
    private let pollerStopBox = PollerStopBox()
    nonisolated(unsafe) private var signalSources: [DispatchSourceSignal] = []
    nonisolated(unsafe) private var requestedPosition: PipPosition?
    nonisolated(unsafe) private var remoteControl: Bool = false

    public init() {}

    public func run(
        sourceID: UInt32,
        destinationID: UInt32,
        size: PipSize,
        position: PipPosition?,
        flip: Flip,
        durationMs: Int?,
        remoteControl: Bool
    ) throws {
        self.requestedPosition = position
        self.remoteControl = remoteControl
        try PermissionProbe.requireScreenRecording(context: "pip")
        if remoteControl {
            try PermissionProbe.requireAccessibility(context: "pip --remote")
        }
        // .accessory: window visible, no dock icon, no menu bar pollution.
        // Workshop spawns dozens of virtual+pip processes; .regular gives every
        // one a generic "exec" tile in the dock, which is unusable.
        runOnMainSetActivationPolicy(.accessory)
        installSignalHandlers()

        let errBox = ErrorBoxPip()
        let started = DispatchSemaphore(value: 0)
        Task { @MainActor in
            do {
                try await self.startStream(
                    sourceID: sourceID,
                    destinationID: destinationID,
                    size: size,
                    flip: flip
                )
            } catch {
                errBox.set(error)
            }
            started.signal()
        }

        let startDeadline = Date(timeIntervalSinceNow: 5.0)
        while started.wait(timeout: .now() + .milliseconds(50)) == .timedOut {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            if Date() > startDeadline { break }
        }
        if let err = errBox.get() { throw err }

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

    public func stop() { lock.withLock { stopRequested = true } }

    // MARK: - private

    private func flagged() -> Bool { lock.withLock { stopRequested } }

    @MainActor
    private func startStream(
        sourceID: UInt32,
        destinationID: UInt32,
        size: PipSize,
        flip: Flip
    ) async throws {
        let remote = self.remoteControl
        // Validate the source display id is something macOS actually has
        // active. Avoid SCShareableContent here — it skips virtual displays.
        guard NSScreen.screens.contains(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
                == CGDirectDisplayID(sourceID)
        }) else {
            throw ProviderError.displayNotFound(sourceID)
        }
        guard let dstScreen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
                == CGDirectDisplayID(destinationID)
        }) else {
            throw ProviderError.displayNotFound(destinationID)
        }

        // Position: explicit (--x/--y, top-left origin from dst) or centered.
        let dstFrame = dstScreen.frame
        let originX: CGFloat
        let originY: CGFloat
        if let pos = self.requestedPosition {
            // Convert top-left origin to AppKit's bottom-left origin.
            originX = dstFrame.origin.x + CGFloat(pos.x)
            originY = dstFrame.origin.y + dstFrame.height - CGFloat(pos.y) - CGFloat(size.height)
        } else {
            originX = dstFrame.origin.x + (dstFrame.width  - CGFloat(size.width))  / 2
            originY = dstFrame.origin.y + (dstFrame.height - CGFloat(size.height)) / 2
        }
        let frame = NSRect(x: originX, y: originY,
                           width: CGFloat(size.width), height: CGFloat(size.height))

        let win = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "wdm pip — display \(sourceID)"
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let bounds = win.contentView!.bounds
        let view: NSView = remote
            ? RemoteControlPipView(frame: bounds, sourceID: CGDirectDisplayID(sourceID))
            : NSView(frame: bounds)
        view.wantsLayer = true
        let imageLayer = CALayer()
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.frame = view.bounds
        imageLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        imageLayer.setAffineTransform(transform(for: flip))
        view.layer?.addSublayer(imageLayer)
        win.contentView = view
        win.makeKeyAndOrderFront(nil)
        // NSWindow's initial contentRect is sometimes ignored when an
        // .accessory-policy app spawns a window before AppKit has fully
        // discovered the multi-display arrangement; the window snaps to
        // the main display. Force-set the frame after orderFront so the
        // window lands on the requested destination display. Verified
        // against issue #4.
        win.setFrame(frame, display: true)
        if remote {
            win.makeFirstResponder(view)
            win.title = "wdm pip — display \(sourceID) [remote]"
        }
        self.window = win

        // Poll CGDisplayCreateImage at 30 Hz: SCStream returns empty frames on
        // idle virtual displays; the legacy CGDisplayCreateImage path reads
        // the framebuffer directly and works for every display.
        let dID = CGDirectDisplayID(sourceID)
        let sink = PipPollingSink(layer: imageLayer)
        self.frameSink = sink
        let stopBox = self.pollerStopBox
        Task.detached(priority: .userInitiated) {
            while !stopBox.flagged() {
                await sink.tick(displayID: dID)
                try? await Task.sleep(nanoseconds: 16_666_666)  // 60 Hz
            }
        }
    }

    private func teardown() {
        pollerStopBox.set()
        captureTimer?.cancel()
        captureTimer = nil
        if let s = stream {
            Task { try? await s.stopCapture() }
        }
        DispatchQueue.main.async { [window] in
            window?.orderOut(nil)
            window?.close()
        }
    }

    private func transform(for flip: Flip) -> CGAffineTransform {
        switch flip {
        case .none:       return .identity
        case .horizontal: return CGAffineTransform(scaleX: -1, y: 1)
        case .vertical:   return CGAffineTransform(scaleX: 1, y: -1)
        case .both:       return CGAffineTransform(scaleX: -1, y: -1)
        }
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
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        signal(SIGHUP, SIG_IGN)
        for sig in [SIGINT, SIGTERM, SIGHUP] as [Int32] {
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in self?.stop() }
            src.resume()
            signalSources.append(src)
        }
    }
}

private final class ErrorBoxPip: @unchecked Sendable {
    private let lock = NSLock()
    private var err: Error?
    func set(_ e: Error) { lock.withLock { err = e } }
    func get() -> Error? { lock.withLock { err } }
}

private final class PollerStopBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    func set() { lock.withLock { stopped = true } }
    func flagged() -> Bool { lock.withLock { stopped } }
}

final class PipPollingSink: NSObject, @unchecked Sendable {
    nonisolated(unsafe) let layer: CALayer
    init(layer: CALayer) {
        self.layer = layer
    }
    func tick(displayID: CGDirectDisplayID) async {
        // Native, in-process capture — replaces the previous shell-out to
        // `/usr/sbin/screencapture`. Process spawn was ~50-100 ms per frame
        // on Apple Silicon, capping the PIP at ~10 fps. CGDisplayCreateImage
        // is in-process (~5-10 ms), giving us 30-60 fps headroom. The cursor
        // is composited on top because CGDisplayCreateImage captures the
        // framebuffer without it.
        guard let frame = CGDisplayCreateImage(displayID) else { return }
        let composed = PipPollingSink.compositeCursor(onto: frame, displayID: displayID)
        let l = self.layer
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            l.contents = composed
            CATransaction.commit()
        }
    }

    /// Composite the current system cursor onto the captured framebuffer
    /// image, but only if the cursor is currently inside the source display.
    /// Returns the input unchanged if no cursor is on this display.
    static func compositeCursor(
        onto frame: CGImage, displayID: CGDirectDisplayID
    ) -> CGImage {
        let bounds = CGDisplayBounds(displayID)
        let cursor = CGEvent(source: nil)?.location ?? .zero
        guard bounds.contains(cursor) else { return frame }

        let cursorImage = NSCursor.current.image
        let hotspot = NSCursor.current.hotSpot
        guard let cursorCG = cursorImage.cgImage(
            forProposedRect: nil, context: nil, hints: nil
        ) else { return frame }

        let pixelW = frame.width
        let pixelH = frame.height
        guard let ctx = CGContext(
            data: nil, width: pixelW, height: pixelH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return frame }
        ctx.draw(frame, in: CGRect(x: 0, y: 0, width: pixelW, height: pixelH))

        let scale = CGFloat(pixelW) / bounds.width
        let local = CGPoint(
            x: cursor.x - bounds.origin.x,
            y: cursor.y - bounds.origin.y
        )
        let cursorW = cursorImage.size.width * scale
        let cursorH = cursorImage.size.height * scale
        let drawX = (local.x - hotspot.x) * scale
        // CGContext is bottom-left; CG display coords are top-left. Flip y.
        let drawY = CGFloat(pixelH) - (local.y - hotspot.y) * scale - cursorH
        ctx.draw(cursorCG, in: CGRect(
            x: drawX, y: drawY, width: cursorW, height: cursorH
        ))
        return ctx.makeImage() ?? frame
    }
}

@objc private final class PipFrameSink: NSObject, SCStreamOutput, @unchecked Sendable {
    nonisolated(unsafe) let layer: CALayer
    init(layer: CALayer) { self.layer = layer }
    @objc func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return }
        let l = self.layer
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            l.contents = cg
            CATransaction.commit()
        }
    }
}

import Foundation
import AppKit
import CoreGraphics
import CoreImage
import CoreMedia
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

    public init() {}

    public func run(
        sourceID: UInt32,
        destinationID: UInt32,
        size: PipSize,
        position: PipPosition?,
        flip: Flip,
        durationMs: Int?
    ) throws {
        self.requestedPosition = position
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
            throw ProviderError.configurationFailed(
                "pip: Screen Recording permission not granted for `wdm`. " +
                "Open System Settings → Privacy & Security → Screen Recording → enable `wdm`."
            )
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

        let view = NSView(frame: win.contentView!.bounds)
        view.wantsLayer = true
        let imageLayer = CALayer()
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.frame = view.bounds
        imageLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        imageLayer.setAffineTransform(transform(for: flip))
        view.layer?.addSublayer(imageLayer)
        win.contentView = view
        win.makeKeyAndOrderFront(nil)
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
                try? await Task.sleep(nanoseconds: 100_000_000)  // 10 Hz
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

private final class PipPollingSink: NSObject, @unchecked Sendable {
    nonisolated(unsafe) let layer: CALayer
    nonisolated(unsafe) private var cachedFilter: Any?
    nonisolated(unsafe) private var cachedConfig: Any?
    init(layer: CALayer) { self.layer = layer }
    func tick(displayID: CGDirectDisplayID) async {
        guard #available(macOS 14.0, *) else { return }
        do {
            // SCShareableContent.current is heavy (XPC + window-server query).
            // Cache the filter+config per sink: only refresh once on first tick,
            // then reuse for every subsequent capture. Cuts per-tick cost ~10x
            // and lets multiple PIPs render concurrently without starving.
            let filter: SCContentFilter
            let cfg: SCStreamConfiguration
            if let f = cachedFilter as? SCContentFilter, let c = cachedConfig as? SCStreamConfiguration {
                filter = f; cfg = c
            } else {
                let content = try await SCShareableContent.current
                guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else { return }
                filter = SCContentFilter(display: scDisplay, excludingWindows: [])
                cfg = SCStreamConfiguration()
                cfg.width = Int(scDisplay.width)
                cfg.height = Int(scDisplay.height)
                cfg.showsCursor = true
                cachedFilter = filter
                cachedConfig = cfg
            }
            let cg = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: cfg
            )
            let l = self.layer
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                l.contents = cg
                CATransaction.commit()
            }
        } catch {
            // Silent — next tick retries.
        }
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

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
    nonisolated(unsafe) private var signalSources: [DispatchSourceSignal] = []

    public init() {}

    public func run(
        sourceID: UInt32,
        destinationID: UInt32,
        size: PipSize,
        flip: Flip,
        durationMs: Int?
    ) throws {
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
            throw ProviderError.configurationFailed(
                "pip: Screen Recording permission not granted for `wdm`. " +
                "Open System Settings → Privacy & Security → Screen Recording, " +
                "enable `wdm`, then re-run. (A prompt was just requested.)"
            )
        }
        runOnMainSetActivationPolicy(.regular)
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
        let content = try await SCShareableContent.current
        guard let scDisplay = content.displays.first(where: { $0.displayID == CGDirectDisplayID(sourceID) }) else {
            throw ProviderError.displayNotFound(sourceID)
        }
        guard let dstScreen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
                == CGDirectDisplayID(destinationID)
        }) else {
            throw ProviderError.displayNotFound(destinationID)
        }

        // Center the PIP window on the destination display.
        let dstFrame = dstScreen.frame
        let originX = dstFrame.origin.x + (dstFrame.width  - CGFloat(size.width))  / 2
        let originY = dstFrame.origin.y + (dstFrame.height - CGFloat(size.height)) / 2
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

        let cfg = SCStreamConfiguration()
        cfg.width = Int(scDisplay.width)
        cfg.height = Int(scDisplay.height)
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        cfg.queueDepth = 5
        cfg.showsCursor = true
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

        let output = PipFrameSink(layer: imageLayer)
        let captureQ = DispatchQueue(label: "wdm.pip.capture", qos: .userInteractive)
        let s = SCStream(filter: filter, configuration: cfg, delegate: nil)
        try s.addStreamOutput(output, type: .screen, sampleHandlerQueue: captureQ)
        try await s.startCapture()
        self.stream = s
        self.frameSink = output
    }

    private func teardown() {
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

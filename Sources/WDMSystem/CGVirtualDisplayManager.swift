import Foundation
import AppKit
import CGVirtualDisplaySPI
import CoreGraphics
import ObjectiveC
import WDMCore

/// Real `VirtualDisplayManager` backed by Apple's `CGVirtualDisplay` SPI in
/// CoreGraphics. The virtual display lives as long as the `CGVirtualDisplay`
/// instance is retained — `run` blocks the calling thread on the main runloop
/// (until `stop()` is called or `durationMs` elapses) while keeping the instance
/// alive, then drops it so WindowServer tears the display down.
public final class CGVirtualDisplayManager: VirtualDisplayManager, @unchecked Sendable {

    private let isSPIAvailable: @Sendable () -> Bool
    private let lock = NSLock()
    private var stopRequested = false
    nonisolated(unsafe) private var display: CGVirtualDisplay?
    nonisolated(unsafe) private var cursorPortal: VirtualCursorPortal?
    nonisolated(unsafe) private var cursorWarper: VirtualCursorEdgeWarper?

    /// Default runtime probe: do the SPI classes still resolve on this macOS?
    public static let defaultSPIProbe: @Sendable () -> Bool = {
        NSClassFromString("CGVirtualDisplay") != nil
            && NSClassFromString("CGVirtualDisplayDescriptor") != nil
            && NSClassFromString("CGVirtualDisplayMode") != nil
            && NSClassFromString("CGVirtualDisplaySettings") != nil
    }

    public init(isSPIAvailable: @escaping @Sendable () -> Bool = CGVirtualDisplayManager.defaultSPIProbe) {
        self.isSPIAvailable = isSPIAvailable
    }

    public func run(spec: VirtualDisplaySpec, durationMs: Int?) throws {
        guard spec.width > 0, spec.height > 0, spec.refreshHz > 0 else {
            throw ProviderError.configurationFailed(
                "virtual: spec must have positive width, height, and refreshHz " +
                "(got \(spec.width)x\(spec.height)@\(spec.refreshHz))"
            )
        }
        guard isSPIAvailable() else {
            throw ProviderError.configurationFailed(
                "virtual: CGVirtualDisplay SPI not available on this macOS — " +
                "no public alternative exists. Track upstream for DriverKit-based " +
                "replacement when Apple opens the entitlement."
            )
        }

        setAccessoryActivationPolicy()

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.name = spec.name
        descriptor.maxPixelsWide = UInt32(spec.width)
        descriptor.maxPixelsHigh = UInt32(spec.height)
        descriptor.sizeInMillimeters = CGSize(width: Double(spec.widthMM),
                                              height: Double(spec.heightMM))
        // WindowServer rejects subsequent virtual displays that reuse a vendor /
        // product / serial triple — derive a unique serial from the spec name +
        // pid so spinning up multiple virtual monitors works in the same login
        // session.
        descriptor.vendorID = 0x76646D00      // 'vdm\0' — wdm vendor
        descriptor.productID = 0x1234
        descriptor.serialNum = Self.uniqueSerial(for: spec.name)
        descriptor.queue = DispatchQueue(label: "wdm.virtual.\(spec.name)")

        let display = CGVirtualDisplay(descriptor: descriptor)
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = spec.hiDPI ? 1 : 0
        settings.modes = [
            CGVirtualDisplayMode(
                width: UInt32(spec.width),
                height: UInt32(spec.height),
                refreshRate: Double(spec.refreshHz)
            )
        ]
        guard display.apply(settings) else {
            throw ProviderError.configurationFailed(
                "virtual: CGVirtualDisplay.apply(settings) returned false " +
                "for \(spec.name) \(spec.width)x\(spec.height)@\(spec.refreshHz)"
            )
        }
        self.display = display
        let portal = VirtualCursorPortal(displayID: display.displayID)
        do {
            try portal.start()
        } catch {
            self.display = nil
            throw error
        }
        self.cursorPortal = portal
        // Polling fallback: WindowServer clamps the cursor at active-display
        // edges before the event tap sees the over-edge delta, so the portal
        // alone isn't enough to make a real mouse drag cross into the virtual.
        // This 60Hz watcher detects the "stuck at edge for ≥3 samples" pattern
        // and warps across.
        let warper = VirtualCursorEdgeWarper(displayID: display.displayID)
        warper.start()
        self.cursorWarper = warper

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
        self.cursorPortal?.stop()
        self.cursorPortal = nil
        self.display = nil  // ARC drops it → WindowServer tears it down.
    }

    public func stop() { lock.withLock { stopRequested = true } }

    private func flagged() -> Bool { lock.withLock { stopRequested } }

    private func setAccessoryActivationPolicy() {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                _ = NSApplication.shared.setActivationPolicy(.accessory)
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    _ = NSApplication.shared.setActivationPolicy(.accessory)
                }
            }
        }
    }

    /// Hash the spec name + pid into a non-zero UInt32 serial unique within
    /// the login session. Plain FNV-1a is overkill but cheap and stable.
    static func uniqueSerial(for name: String) -> UInt32 {
        var hash: UInt32 = 2166136261
        for byte in name.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        let pid = UInt32(truncatingIfNeeded: ProcessInfo.processInfo.processIdentifier)
        return (hash ^ pid) | 0x1     // never zero
    }

}

import Foundation
import CGVirtualDisplaySPI
import CoreGraphics
import ObjectiveC
import WDMCore

/// Real `VirtualDisplayManager` backed by Apple's `CGVirtualDisplay` SPI in
/// CoreGraphics. The virtual display lives as long as the `CGVirtualDisplay`
/// instance is retained — `run` blocks the calling thread on the main runloop
/// (until SIGTERM/SIGINT/SIGHUP or `durationMs` elapses) while keeping the
/// instance alive, then drops it so WindowServer tears the display down.
///
/// Honest unsupported-path: probes via `objc_getClass("CGVirtualDisplay")` at
/// runtime and refuses with a typed error if the symbol is gone in some
/// future macOS. Same shape as `IOKitRotation.isSupported`.
public final class CGVirtualDisplayManager: VirtualDisplayManager, @unchecked Sendable {

    private let isSPIAvailable: @Sendable () -> Bool
    private let lock = NSLock()
    private var stopRequested = false
    nonisolated(unsafe) private var display: CGVirtualDisplay?
    nonisolated(unsafe) private var signalSources: [DispatchSourceSignal] = []

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

        installSignalHandlers()

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.name = spec.name
        descriptor.maxPixelsWide = UInt32(spec.width)
        descriptor.maxPixelsHigh = UInt32(spec.height)
        descriptor.sizeInMillimeters = CGSize(width: Double(spec.widthMM),
                                              height: Double(spec.heightMM))
        descriptor.serialNum = 0x57444D31     // 'WDM1'
        descriptor.productID = 0x1234
        descriptor.vendorID = 0x76646D00      // 'vdm\0'
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
        self.display = nil  // ARC drops it → WindowServer tears it down.
    }

    public func stop() { lock.withLock { stopRequested = true } }

    private func flagged() -> Bool { lock.withLock { stopRequested } }

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

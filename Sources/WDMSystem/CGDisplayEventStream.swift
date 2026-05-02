import Foundation
import CoreGraphics
import WDMCore

/// Real-hardware `DisplayEventStream` backed by `CGDisplayRegisterReconfigurationCallback`.
/// Each instance produces one async stream; cancelling it unregisters the callback.
public final class CGDisplayEventStream: DisplayEventStream, @unchecked Sendable {

    public init() {}

    public var events: AsyncThrowingStream<DisplayEvent, Error> {
        AsyncThrowingStream { continuation in
            let ctx = Context(continuation: continuation)
            let opaque = Unmanaged.passRetained(ctx).toOpaque()
            let err = CGDisplayRegisterReconfigurationCallback(reconfigCallback, opaque)
            if err != .success {
                Unmanaged<Context>.fromOpaque(opaque).release()
                continuation.finish(
                    throwing: ProviderError.configurationFailed(
                        "CGDisplayRegisterReconfigurationCallback: \(err.rawValue)"
                    )
                )
                return
            }
            let address = UInt(bitPattern: opaque)
            continuation.onTermination = { _ in
                guard let ptr = UnsafeMutableRawPointer(bitPattern: address) else { return }
                CGDisplayRemoveReconfigurationCallback(reconfigCallback, ptr)
                Unmanaged<Context>.fromOpaque(ptr).release()
            }
        }
    }

    // MARK: - pure translation (tested in isolation)

    /// Map a single CG reconfiguration callback (one displayID + flag bitmask) to zero
    /// or more `DisplayEvent`s. Pure; no I/O. Tested with synthetic flags.
    public static func translate(
        displayID: UInt32, flags: UInt32, now: Date
    ) -> [DisplayEvent] {
        if flags & CGDisplayChangeSummaryFlags.beginConfigurationFlag.rawValue != 0 {
            return []
        }

        var out: [DisplayEvent] = []
        func emit(_ kind: DisplayEvent.Kind) {
            out.append(DisplayEvent(timestamp: now, kind: kind, displayID: displayID))
        }
        let added = CGDisplayChangeSummaryFlags.addFlag.rawValue
            | CGDisplayChangeSummaryFlags.enabledFlag.rawValue
        let removed = CGDisplayChangeSummaryFlags.removeFlag.rawValue
            | CGDisplayChangeSummaryFlags.disabledFlag.rawValue
        let moved = CGDisplayChangeSummaryFlags.movedFlag.rawValue
            | CGDisplayChangeSummaryFlags.desktopShapeChangedFlag.rawValue
        let mirror = CGDisplayChangeSummaryFlags.mirrorFlag.rawValue
            | CGDisplayChangeSummaryFlags.unMirrorFlag.rawValue

        if flags & added != 0 { emit(.added) }
        if flags & removed != 0 { emit(.removed) }
        if flags & CGDisplayChangeSummaryFlags.setMainFlag.rawValue != 0 { emit(.mainChanged) }
        if flags & CGDisplayChangeSummaryFlags.setModeFlag.rawValue != 0 { emit(.modeChanged) }
        if flags & moved != 0 { emit(.moved) }
        if flags & mirror != 0 { emit(.mirrorChanged) }
        return out
    }

    // MARK: - C callback plumbing

    fileprivate final class Context {
        let continuation: AsyncThrowingStream<DisplayEvent, Error>.Continuation
        init(continuation: AsyncThrowingStream<DisplayEvent, Error>.Continuation) {
            self.continuation = continuation
        }
        func handle(displayID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
            for event in CGDisplayEventStream.translate(
                displayID: displayID, flags: flags.rawValue, now: Date()
            ) {
                continuation.yield(event)
            }
        }
    }
}

private let reconfigCallback: CGDisplayReconfigurationCallBack = { displayID, flags, userInfo in
    guard let userInfo else { return }
    let ctx = Unmanaged<CGDisplayEventStream.Context>.fromOpaque(userInfo).takeUnretainedValue()
    ctx.handle(displayID: displayID, flags: flags)
}

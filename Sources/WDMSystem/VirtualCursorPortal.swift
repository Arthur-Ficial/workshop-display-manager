import CoreGraphics
import Foundation

final class VirtualCursorPortal: @unchecked Sendable {
    private let displayID: CGDirectDisplayID
    private let lock = NSLock()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var runLoop: CFRunLoop?

    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
    }

    func start() throws {
        try lock.withLock {
            guard tap == nil else { return }
            let tap = try makeTap()
            let source = try makeSource(for: tap)
            attach(tap: tap, source: source)
        }
    }

    func stop() {
        lock.withLock {
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
            if let runLoop, let source {
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
            }
            tap = nil
            source = nil
            runLoop = nil
        }
    }

    private func route(event: CGEvent) -> Unmanaged<CGEvent>? {
        let delta = CGVector(
            dx: CGFloat(event.getIntegerValueField(.mouseEventDeltaX)),
            dy: CGFloat(event.getIntegerValueField(.mouseEventDeltaY))
        )
        guard delta.dx != 0 || delta.dy != 0 else {
            return Unmanaged.passUnretained(event)
        }
        let router = VirtualCursorPortalRouter(targetDisplayID: displayID)
        if let route = router.route(location: event.location, delta: delta, displays: Self.activeDisplays()) {
            event.location = route.globalPoint
        }
        return Unmanaged.passUnretained(event)
    }

    private func makeTap() throws -> CFMachPort {
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask(),
            callback: { proxy, type, event, userInfo in
                VirtualCursorPortal.callback(proxy: proxy, type: type, event: event, userInfo: userInfo)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw ProviderError.configurationFailed(
                "virtual: cursor edge portal event tap unavailable; " +
                "grant Accessibility and Input Monitoring permission to `wdm`"
            )
        }
        return tap
    }

    private func makeSource(for tap: CFMachPort) throws -> CFRunLoopSource {
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            throw ProviderError.configurationFailed(
                "virtual: cursor edge portal run loop source unavailable"
            )
        }
        return source
    }

    private func attach(tap: CFMachPort, source: CFRunLoopSource) {
        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        self.runLoop = runLoop
    }

    private static func callback(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        userInfo: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            return Unmanaged.passUnretained(event)
        }
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let portal = Unmanaged<VirtualCursorPortal>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        return portal.route(event: event)
    }

    private static func eventMask() -> CGEventMask {
        let types: [CGEventType] = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
        ]
        return types.reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << CGEventMask($1.rawValue))
        }
    }

    private static func activeDisplays() -> [VirtualCursorPortalRouter.Display] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map {
            VirtualCursorPortalRouter.Display(id: $0, bounds: CGDisplayBounds($0))
        }
    }
}

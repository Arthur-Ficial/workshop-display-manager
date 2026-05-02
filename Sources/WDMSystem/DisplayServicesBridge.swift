import Foundation
import CoreGraphics

/// Thin wrapper over the private `DisplayServices.framework` symbols for
/// brightness control. We use dlopen/dlsym so an absent symbol just means
/// "brightness unsupported" instead of a link-time failure.
enum DisplayServicesBridge {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    nonisolated(unsafe) private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    nonisolated(unsafe) private static let getFn: GetFn? = {
        guard let h = handle, let s = dlsym(h, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(s, to: GetFn.self)
    }()

    nonisolated(unsafe) private static let setFn: SetFn? = {
        guard let h = handle, let s = dlsym(h, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(s, to: SetFn.self)
    }()

    static func get(_ id: CGDirectDisplayID) -> Float? {
        guard let f = getFn else { return nil }
        var b: Float = 0
        let err = f(id, &b)
        guard err == 0 else { return nil }
        return b
    }

    static func set(_ id: CGDirectDisplayID, _ value: Float) -> Bool {
        guard let f = setFn else { return false }
        return f(id, value) == 0
    }
}

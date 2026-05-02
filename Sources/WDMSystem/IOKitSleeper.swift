import Foundation
import IOKit
import IOKit.pwr_mgt

/// Real `Sleeper` backed by `IOPMSleepSystem`. Public IOKit, no shell-out
/// to `pmset`. Requires no special entitlements: any GUI-session process
/// can request sleep on the machine it's logged into.
public final class IOKitSleeper: Sleeper {
    public init() {}

    public func sleepNow() throws {
        // Acquire an io_connect_t to IOPMrootDomain via IORegisterForSystemPower,
        // which is the public, sandbox-friendly path. We don't need power-state
        // notifications, so the callback is a no-op.
        var notifyPort: IONotificationPortRef?
        var notifier: io_object_t = 0
        let port = IORegisterForSystemPower(
            nil, &notifyPort, { _, _, _, _ in }, &notifier
        )
        guard port != MACH_PORT_NULL else {
            throw ProviderError.configurationFailed(
                "sleep: IORegisterForSystemPower returned MACH_PORT_NULL"
            )
        }
        defer {
            IODeregisterForSystemPower(&notifier)
            if let notifyPort {
                IONotificationPortDestroy(notifyPort)
            }
            IOServiceClose(port)
        }
        let kr = IOPMSleepSystem(port)
        guard kr == kIOReturnSuccess else {
            throw ProviderError.configurationFailed(
                "sleep: IOPMSleepSystem failed (kr=\(kr))"
            )
        }
    }
}

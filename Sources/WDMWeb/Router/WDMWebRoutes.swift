import Foundation
import WDMKit

/// One-stop route table for WDMWeb. Add a verb here, the server picks it up.
public enum WDMWebRoutes {
    public static let all: [WDMWebRoute] = [
        // Visual index — opens in a browser to see the live arrangement
        WDMWebRoute(method: "GET", pattern: "/", handler: WDMWebIndexHandler.handle),

        // Reads
        WDMWebRoute(method: "GET", pattern: "/version", handler: { _, _, _ in
            .okText("wdm \(WDMCore.version)\n")
        }),
        WDMWebRoute(method: "GET", pattern: "/displays", handler: WDMWebDisplayHandlers.list),
        WDMWebRoute(method: "GET", pattern: "/displays/{alias}", handler: WDMWebDisplayHandlers.get),
        WDMWebRoute(method: "GET", pattern: "/displays/{alias}/modes", handler: WDMWebDisplayHandlers.modes),
        WDMWebRoute(method: "GET", pattern: "/profiles", handler: WDMWebProfileHandlers.list),
        WDMWebRoute(method: "GET", pattern: "/displays/{alias}/brightness",
                    handler: WDMWebMonitorControlHandlers.brightnessGet),
        WDMWebRoute(method: "GET", pattern: "/doctor/probe", handler: WDMWebDoctorHandlers.probe),
        WDMWebRoute(method: "GET", pattern: "/doctor/probe/{alias}", handler: WDMWebDoctorHandlers.probe),
        WDMWebRoute(method: "GET", pattern: "/virtual/presets", handler: WDMWebVirtualHandlers.presets),
        WDMWebRoute(method: "GET", pattern: "/virtual", handler: WDMWebVirtualHandlers.list),

        // Mutations on a single display
        WDMWebRoute(method: "POST", pattern: "/displays/{alias}/mode", handler: WDMWebDisplayHandlers.setMode),
        WDMWebRoute(method: "POST", pattern: "/displays/{alias}/main", handler: WDMWebDisplayHandlers.setMain),
        WDMWebRoute(method: "POST", pattern: "/displays/{alias}/move", handler: WDMWebDisplayHandlers.move),
        WDMWebRoute(method: "POST", pattern: "/displays/{alias}/rotate", handler: WDMWebDisplayHandlers.rotate),
        WDMWebRoute(method: "POST", pattern: "/displays/{alias}/flip", handler: WDMWebDisplayHandlers.flip),
        WDMWebRoute(method: "POST", pattern: "/displays/{alias}/brightness",
                    handler: WDMWebMonitorControlHandlers.brightnessSet),
        WDMWebRoute(method: "POST", pattern: "/displays/{alias}/hdr", handler: WDMWebMonitorControlHandlers.hdr),

        // Cross-display sequences
        WDMWebRoute(method: "POST", pattern: "/switch", handler: WDMWebSequenceHandlers.switchMain),
        WDMWebRoute(method: "POST", pattern: "/cycle", handler: WDMWebSequenceHandlers.cycleMain),
        WDMWebRoute(method: "POST", pattern: "/mirror", handler: WDMWebMirrorHandlers.mirror),
        WDMWebRoute(method: "POST", pattern: "/unmirror", handler: WDMWebMirrorHandlers.unmirror),
        WDMWebRoute(method: "POST", pattern: "/sleep", handler: WDMWebSequenceHandlers.sleep),

        // Profiles
        WDMWebRoute(method: "POST", pattern: "/profiles", handler: WDMWebProfileHandlers.save),
        WDMWebRoute(method: "POST", pattern: "/profiles/{name}/restore", handler: WDMWebProfileHandlers.restore),
        WDMWebRoute(method: "DELETE", pattern: "/profiles/{name}", handler: WDMWebProfileHandlers.remove),

        // Live arrangement
        WDMWebRoute(method: "GET", pattern: "/arrangement", handler: WDMWebArrangementHandlers.read),
        WDMWebRoute(method: "POST", pattern: "/arrangement", handler: WDMWebArrangementHandlers.write),

        // Capture
        WDMWebRoute(method: "POST", pattern: "/screenshot", handler: WDMWebCaptureHandlers.screenshot),
        WDMWebRoute(method: "POST", pattern: "/panorama", handler: WDMWebCaptureHandlers.panorama),
        WDMWebRoute(method: "POST", pattern: "/shot-all", handler: WDMWebCaptureHandlers.shotAll),
    ]
}

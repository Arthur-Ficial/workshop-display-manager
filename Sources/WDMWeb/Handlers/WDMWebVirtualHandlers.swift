import Foundation
import WDMKit

public enum WDMWebVirtualHandlers {
    public static func presets(_: WDMWebRequest, _: [String: String], _: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let presets = WDMController.virtual.presets().map {
                ["name": $0.name, "label": $0.label,
                 "width": "\($0.width)", "height": "\($0.height)",
                 "refreshHz": "\($0.refreshHz)", "hiDPI": "\($0.hiDPI)"]
            }
            return .ok(try WDMWebHandlerSupport.encodeJSON(presets))
        }
    }

    public static func list(_: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let displays = try WDMController.virtual.list(provider: deps.provider)
            return .ok(try WDMWebHandlerSupport.encodeJSON(displays))
        }
    }
}

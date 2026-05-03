import Foundation
import WDMKit

public enum WDMWebDoctorHandlers {
    public static func probe(_: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"]
            let reports = try deps.controller.doctorProbe(alias: alias)
            return .ok(try WDMWebHandlerSupport.encodeJSON(reports))
        }
    }
}

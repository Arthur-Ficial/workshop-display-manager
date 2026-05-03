import Foundation
import WDMKit

public enum WDMWebSequenceHandlers {
    public static func switchMain(_: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let result = try deps.controller.switchMain(confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }

    public static func cycleMain(_: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let result = try deps.controller.cycleMain(confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }

    public static func sleep(_: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            try deps.controller.sleep(using: deps.sleeper)
            return .ok(Data("{\"slept\":true}".utf8))
        }
    }
}

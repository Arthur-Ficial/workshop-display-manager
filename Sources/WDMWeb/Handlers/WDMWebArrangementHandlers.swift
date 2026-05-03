import Foundation
import WDMKit

/// `GET /arrangement` returns the live layout (origin + rotation per display);
/// `POST /arrangement` applies a bulk plan in one safe transaction. Designed
/// for drag-to-rearrange GUIs and other live editors.
public enum WDMWebArrangementHandlers {
    public static func read(_: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let entries = try deps.controller.arrangement()
            return .ok(try WDMWebHandlerSupport.encodeJSON(entries))
        }
    }

    public static func write(req: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let entries = try WDMWebHandlerSupport.decodeBody([ArrangementEntry].self, req)
            let result = try deps.controller.setArrangement(entries, confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }
}

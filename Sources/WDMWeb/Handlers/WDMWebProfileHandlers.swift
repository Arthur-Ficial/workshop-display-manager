import Foundation
import WDMKit

public enum WDMWebProfileHandlers {
    public struct SaveBody: Codable, Sendable { public let name: String }

    public static func list(_: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            return .ok(try WDMWebHandlerSupport.encodeJSON(try deps.controller.profiles()))
        }
    }

    public static func save(req: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let body = try WDMWebHandlerSupport.decodeBody(SaveBody.self, req)
            try deps.controller.saveProfile(body.name)
            return .ok(Data("{\"saved\":\"\(body.name)\"}".utf8))
        }
    }

    public static func restore(_: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let name = params["name"] ?? ""
            let result = try deps.controller.restoreProfile(name, confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }

    public static func remove(_: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let name = params["name"] ?? ""
            try deps.controller.removeProfile(name)
            return .ok(Data("{\"removed\":\"\(name)\"}".utf8))
        }
    }
}

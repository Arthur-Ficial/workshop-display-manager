import Foundation
import WDMKit

public enum WDMWebMonitorControlHandlers {
    public struct BrightnessBody: Codable, Sendable { public let value: Float }

    public static func brightnessGet(_: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            let v = try deps.controller.brightness(alias)
            let payload = "{\"value\":\(v.map { "\($0)" } ?? "null")}"
            return .ok(Data(payload.utf8))
        }
    }

    public static func brightnessSet(req: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            let body = try WDMWebHandlerSupport.decodeBody(BrightnessBody.self, req)
            let result = try deps.controller.brightness(alias, value: body.value, confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }

    public struct HDRBody: Codable, Sendable { public let on: Bool }

    public static func hdr(req: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            let body = try WDMWebHandlerSupport.decodeBody(HDRBody.self, req)
            try deps.controller.setHDR(alias, enabled: body.on, using: deps.hdrProvider)
            return .ok(Data("{\"hdr\":\(body.on)}".utf8))
        }
    }
}

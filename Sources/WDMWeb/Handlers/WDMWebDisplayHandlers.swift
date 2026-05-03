import Foundation
import WDMKit

/// Display read + mutation handlers. Each handler is one verb.
public enum WDMWebDisplayHandlers {
    public static func list(_: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let displays = try deps.controller.list()
            return .ok(try WDMWebHandlerSupport.encodeJSON(displays))
        }
    }

    public static func get(_: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            return .ok(try WDMWebHandlerSupport.encodeJSON(try deps.controller.get(alias)))
        }
    }

    public static func modes(_: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            return .ok(try WDMWebHandlerSupport.encodeJSON(try deps.controller.modes(alias)))
        }
    }

    public struct ModeBody: Codable, Sendable { public let mode: String }

    public static func setMode(req: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            let body = try WDMWebHandlerSupport.decodeBody(ModeBody.self, req)
            let mode = try Mode.parse(body.mode)
            let result = try deps.controller.mode(alias, mode: mode, confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }

    public static func setMain(_: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            let result = try deps.controller.main(alias, confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }

    public struct MoveBody: Codable, Sendable { public let x: Int; public let y: Int }

    public static func move(req: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            let body = try WDMWebHandlerSupport.decodeBody(MoveBody.self, req)
            let result = try deps.controller.move(alias, to: Point(x: body.x, y: body.y),
                                                  confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }

    public struct RotateBody: Codable, Sendable { public let degrees: Int }

    public static func rotate(req: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            let body = try WDMWebHandlerSupport.decodeBody(RotateBody.self, req)
            let result = try deps.controller.rotate(alias, degrees: body.degrees,
                                                    confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }

    public struct FlipBody: Codable, Sendable { public let flip: String }

    public static func flip(req: WDMWebRequest, params: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let alias = params["alias"] ?? ""
            let body = try WDMWebHandlerSupport.decodeBody(FlipBody.self, req)
            guard let flip = Flip.parse(body.flip) else {
                throw WDMError.usage("flip: bad axis '\(body.flip)'")
            }
            let result = try deps.controller.flip(alias, flip: flip, confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }
}

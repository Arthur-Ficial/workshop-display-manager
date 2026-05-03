import Foundation
import WDMKit

public enum WDMWebMirrorHandlers {
    public struct MirrorBody: Codable, Sendable {
        public let source: String
        public let targets: [String]
    }

    public static func mirror(req: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let body = try WDMWebHandlerSupport.decodeBody(MirrorBody.self, req)
            let result = try deps.controller.mirror(
                source: body.source, targets: body.targets, confirmer: AutoYesConfirmer()
            )
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }

    public struct UnmirrorBody: Codable, Sendable { public let alias: String }

    public static func unmirror(req: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let body = try WDMWebHandlerSupport.decodeBody(UnmirrorBody.self, req)
            let result = try deps.controller.unmirror(body.alias, confirmer: AutoYesConfirmer())
            return .ok(Data("{\"result\":\"\(result)\"}".utf8))
        }
    }
}

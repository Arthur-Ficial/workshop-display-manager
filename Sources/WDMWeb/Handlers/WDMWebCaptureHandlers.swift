import Foundation
import WDMKit

public enum WDMWebCaptureHandlers {
    public struct ScreenshotBody: Codable, Sendable {
        public let alias: String
        public let path: String
    }

    public static func screenshot(req: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let body = try WDMWebHandlerSupport.decodeBody(ScreenshotBody.self, req)
            try deps.controller.screenshot(
                body.alias, to: URL(fileURLWithPath: body.path), using: deps.screenshotter
            )
            return .ok(Data("{\"path\":\"\(body.path)\"}".utf8))
        }
    }

    public struct PanoramaBody: Codable, Sendable { public let path: String }

    public static func panorama(req: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let body = try WDMWebHandlerSupport.decodeBody(PanoramaBody.self, req)
            let result = try deps.controller.panorama(
                to: URL(fileURLWithPath: body.path), using: deps.screenshotter
            )
            return .ok(try WDMWebHandlerSupport.encodeJSON([
                "path": result.outputURL.path,
                "displayCount": "\(result.displayCount)",
                "totalWidth": "\(result.totalWidth)",
                "height": "\(result.height)"
            ]))
        }
    }

    public struct ShotAllBody: Codable, Sendable { public let directory: String }

    public static func shotAll(req: WDMWebRequest, _: [String: String], deps: WDMWebDeps) -> WDMWebResponse {
        WDMWebHandlerSupport.run {
            let body = try WDMWebHandlerSupport.decodeBody(ShotAllBody.self, req)
            let urls = try deps.controller.shotAll(
                to: URL(fileURLWithPath: body.directory), using: deps.screenshotter
            )
            return .ok(try WDMWebHandlerSupport.encodeJSON(urls.map(\.path)))
        }
    }
}

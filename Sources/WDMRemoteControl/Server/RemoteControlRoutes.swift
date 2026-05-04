import Foundation

/// Pure routing layer — turns a parsed `RemoteRequest` + a `RemoteControllable`
/// into a `RemoteResponse`. M1 ships `GET /ui/snapshot`, `POST /ui/click`,
/// `POST /ui/dispatch` (raw action), `GET /ui/version`.
public enum RemoteControlRoutes {
    public static func dispatch(
        request: RemoteRequest,
        target: RemoteControllable,
        version: String
    ) -> RemoteResponse {
        switch (request.method, request.path) {
        case ("GET", "/ui/version"):
            return version200(version)
        case ("GET", let p) where p == "/ui/snapshot" || p.hasPrefix("/ui/snapshot?"):
            return snapshot(target: target, query: query(p))
        case ("POST", "/ui/click"):
            return clickFromBody(request.body, target: target)
        case ("POST", "/ui/closeWindow"):
            return rawDispatchWithVerb(request.body, verb: "closeWindow", target: target)
        case ("POST", "/ui/raiseWindow"):
            return rawDispatchWithVerb(request.body, verb: "raiseWindow", target: target)
        case ("POST", "/ui/keystroke"):
            return rawDispatchWithVerb(request.body, verb: "keystroke", target: target)
        case ("POST", "/ui/wait"):
            return rawDispatchWithVerb(request.body, verb: "waitForRemoteID", target: target)
        case ("POST", "/ui/invokeMenu"):
            return rawDispatchWithVerb(request.body, verb: "invokeMenu", target: target)
        case ("GET", let p) where p == "/ui/screenshot" || p.hasPrefix("/ui/screenshot?"):
            return screenshotFromQuery(query: query(p), target: target)
        case ("POST", "/ui/dispatch"):
            return rawDispatch(request.body, target: target)
        default:
            return .error(status: 404, message: "no route for \(request.method) \(request.path)")
        }
    }

    private static func version200(_ v: String) -> RemoteResponse {
        let payload = #"{"server":"\#(v)"}"#
        return .ok(Data(payload.utf8))
    }

    private static func snapshot(target: RemoteControllable, query: [String: String]) -> RemoteResponse {
        let interactive = (query["interactive"] ?? "0") == "1"
        do {
            let tree = try target.snapshot(interactive: interactive)
            return .ok(try SceneTreeJSON.encode(tree))
        } catch {
            return .error(status: 500, message: "\(error)")
        }
    }

    private static func clickFromBody(_ body: Data, target: RemoteControllable) -> RemoteResponse {
        guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let raw = obj["ref"] as? String, let ref = Ref(raw) else {
            return .error(status: 400, message: "click body needs {\"ref\":\"@e<n>\"}")
        }
        return run(action: .click(ref: ref), target: target)
    }

    /// Decode `body` as a partial action object missing the `action` field,
    /// inject the verb, and run. Lets us register one route per verb without
    /// re-implementing the JSON shape per route.
    private static func rawDispatchWithVerb(_ body: Data, verb: String,
                                            target: RemoteControllable) -> RemoteResponse {
        var obj: [String: Any] = [:]
        if let parsed = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            obj = parsed
        }
        obj["action"] = verb
        let action: RemoteAction
        do { action = try RemoteActionJSON.decode(object: obj) }
        catch { return .error(status: 400, message: "\(error)") }
        return run(action: action, target: target)
    }

    private static func screenshotFromQuery(query: [String: String],
                                            target: RemoteControllable) -> RemoteResponse {
        let action = RemoteAction.screenshot(window: query["window"])
        do {
            let result = try target.dispatch(action)
            // The adapter stuffs base64 PNG into result.reason for transport.
            // We re-emit as raw image bytes so curl > out.png Just Works.
            if result.ok, let b64 = result.reason, let data = Data(base64Encoded: b64) {
                return RemoteResponse(status: 200, body: data, contentType: "image/png")
            }
            return .error(status: result.error == "stale-ref" ? 404 : 503,
                          message: result.error ?? "screenshot failed")
        } catch {
            return .error(status: 500, message: "\(error)")
        }
    }

    private static func rawDispatch(_ body: Data, target: RemoteControllable) -> RemoteResponse {
        let action: RemoteAction
        do { action = try RemoteActionJSON.decode(body) }
        catch { return .error(status: 400, message: "\(error)") }
        return run(action: action, target: target)
    }

    private static func run(action: RemoteAction, target: RemoteControllable) -> RemoteResponse {
        do {
            let result = try target.dispatch(action)
            return .ok(try ActionResultJSON.encode(result))
        } catch {
            return .error(status: 500, message: "\(error)")
        }
    }

    private static func query(_ path: String) -> [String: String] {
        guard let q = path.split(separator: "?", maxSplits: 1).dropFirst().first else { return [:] }
        var out: [String: String] = [:]
        for pair in q.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                out[String(kv[0])] = String(kv[1])
            } else {
                out[String(kv[0])] = ""
            }
        }
        return out
    }
}

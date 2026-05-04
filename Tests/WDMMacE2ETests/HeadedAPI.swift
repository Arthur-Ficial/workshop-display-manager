import Foundation
@testable import WDMRemoteControl

/// DRY API client for headed e2e tests. Every test that talks to a running
/// `wdm-mac --remote` instance uses this; nobody hand-rolls URLSession
/// boilerplate. Methods read top-to-bottom so tests stay narrative.
struct HeadedAPI {
    let port: UInt16
    private var base: String { "http://127.0.0.1:\(port)" }

    /// `GET /ui/snapshot` — decoded.
    func snapshot() async throws -> SceneTree {
        try SceneTreeJSON.decode(try await getRaw("/ui/snapshot"))
    }

    /// `GET <path>` — raw bytes (use for /ui/screenshot).
    func getRaw(_ path: String) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "\(base)\(path)")!)
        return data
    }

    /// `POST <path>` with a JSON body. Returns the response body, parsed.
    @discardableResult
    func post(_ path: String, _ body: String) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "\(base)\(path)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data(body.utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// `POST /ui/click {ref}` returning the parsed `ActionResult` body.
    @discardableResult
    func click(ref: Ref) async throws -> [String: Any] {
        try await post("/ui/click", #"{"ref":"\#(ref.rawValue)"}"#)
    }

    /// `POST /ui/click` for the first node matching `remoteID`. Throws if
    /// no matching button exists in the current snapshot.
    @discardableResult
    func clickRemoteID(_ remoteID: String) async throws -> [String: Any] {
        let tree = try await snapshot()
        guard let node = tree.nodes.first(where: {
            $0.remoteID == remoteID && $0.role == "button"
        }) else {
            throw HeadedTestError.noButton(remoteID: remoteID)
        }
        return try await click(ref: node.ref)
    }

    @discardableResult
    func closeWindow(named name: String) async throws -> [String: Any] {
        try await post("/ui/closeWindow", #"{"name":"\#(name)"}"#)
    }

    @discardableResult
    func raiseWindow(named name: String) async throws -> [String: Any] {
        try await post("/ui/raiseWindow", #"{"name":"\#(name)"}"#)
    }

    @discardableResult
    func invokeMenu(_ selector: String) async throws -> [String: Any] {
        try await post("/ui/invokeMenu", #"{"selector":"\#(selector)"}"#)
    }

    @discardableResult
    func waitFor(remoteID: String, timeoutMs: Int = 3000) async throws -> [String: Any] {
        try await post("/ui/wait",
                       #"{"remoteID":"\#(remoteID)","timeoutMs":\#(timeoutMs)}"#)
    }

    /// `GET /ui/screenshot[?window=<name>]` → PNG bytes.
    func screenshot(window: String? = nil) async throws -> Data {
        let q = window.map { "?window=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)" } ?? ""
        return try await getRaw("/ui/screenshot\(q)")
    }
}

enum HeadedTestError: Error, CustomStringConvertible {
    case noButton(remoteID: String)
    var description: String {
        switch self {
        case .noButton(let id): "no AXButton with remoteID '\(id)' in snapshot"
        }
    }
}

/// Common gate — every headed test starts with this.
func headedEnabled() -> Bool {
    ProcessInfo.processInfo.environment["WDM_HEADED_E2E"] == "1"
}

/// Get the shared instance + ready-to-use API client. Used by every read-only
/// headed test so they share one wdm-mac process.
@MainActor
func sharedHeadedAPI() throws -> HeadedAPI {
    let inst = try HeadedAppInstance.shared()
    return HeadedAPI(port: inst.port)
}

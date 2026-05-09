import SwiftUI
import WebKit

/// Embeds the Stage canvas in a `WKWebView`. The Stage is the only
/// WebKit-rendered surface in WDMMac; the rest of the app stays 100%
/// native SwiftUI/AppKit. The bridge is intentionally tiny:
///
///   Swift → JS:  `window.wdm.setState(...)`  via evaluateJavaScript.
///   JS → Swift:  `window.webkit.messageHandlers.wdm.postMessage(...)`.
///
/// All payloads are JSON-encodable values; the message types are listed
/// in `StageMessage`.
public struct StageWebView: NSViewRepresentable {
    public let state: StageState
    public let onMessage: (StageMessage) -> Void

    public init(state: StageState, onMessage: @escaping (StageMessage) -> Void) {
        self.state = state
        self.onMessage = onMessage
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onMessage: onMessage)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "wdm")
        let web = WKWebView(frame: .zero, configuration: config)
        web.setValue(false, forKey: "drawsBackground")    // transparent under chrome
        web.allowsBackForwardNavigationGestures = false
        if let url = Bundle.module.url(forResource: "index", withExtension: "html",
                                       subdirectory: "stage") {
            // Read access broadened to root so the Stage's tile background
            // CSS can load `file://` wallpaper images from
            // /System/Library/Desktop Pictures, /Users/.../Pictures, etc.
            // WDMMac is non-sandboxed (entitlements: app-sandbox=false),
            // so this matches the host's existing privilege.
            web.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }
        context.coordinator.webView = web
        return web
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.pendingState = state
            context.coordinator.flushIfReady()
        }
    }

    public final class Coordinator: NSObject, WKScriptMessageHandler, @unchecked Sendable {
        weak var webView: WKWebView?
        var pendingState: StageState?
        private var ready = false
        private let onMessage: (StageMessage) -> Void

        init(onMessage: @escaping (StageMessage) -> Void) {
            self.onMessage = onMessage
        }

        // WKScriptMessageHandler is delivered on the main thread by
        // WebKit. We accept it nonisolated and then dispatch the body
        // read + onMessage call back onto the main queue explicitly so
        // Swift 6's actor-isolation runtime check doesn't trip.
        public func userContentController(
            _ uc: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // `message.body` is a plain Foundation object (NSDictionary)
            // — read it here on whatever thread WK delivered us on,
            // then bounce to main for the side effects.
            let body = message.body as? [String: Any]
            DispatchQueue.main.async {
                guard let body, let parsed = StageMessage(json: body) else { return }
                if case .ready = parsed { self.ready = true; self.flushIfReady() }
                self.onMessage(parsed)
            }
        }

        func flushIfReady() {
            dispatchPrecondition(condition: .onQueue(.main))
            guard ready, let s = pendingState, let web = webView else { return }
            guard let data = try? JSONEncoder().encode(s),
                  let json = String(data: data, encoding: .utf8) else { return }
            web.evaluateJavaScript("window.wdm.setState(\(json));", completionHandler: nil)
        }
    }
}

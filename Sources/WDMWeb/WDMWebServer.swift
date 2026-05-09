import Foundation
import Network
import WDMKit

/// Tiny HTTP server backed by Apple's Network framework — no third-party deps.
/// Single connection per request (Connection: close), good enough for local
/// CLI/web bridging traffic.
public final class WDMWebServer: @unchecked Sendable {
    private let listener: NWListener
    public let port: UInt16
    private let deps: WDMWebDeps
    private let router: WDMWebRouter
    private let queue = DispatchQueue(label: "wdm.web.server")

    public init(host: String, port: UInt16, deps: WDMWebDeps,
                router: WDMWebRouter = WDMWebRouter(routes: WDMWebRoutes.all)) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        // Bind to localhost only (security: no remote access by default).
        if let tcp = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
        }
        let listenPort = NWEndpoint.Port(rawValue: port) ?? .any
        self.listener = try NWListener(using: parameters, on: listenPort)
        self.deps = deps
        self.router = router
        self.port = port
    }

    public func run() {
        startAccepting()
        listener.start(queue: queue)
        dispatchMain()
    }

    public func runAsync() {
        startAccepting()
        listener.start(queue: queue)
    }

    public func stop() { listener.cancel() }

    private func startAccepting() {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection: connection, accumulated: Data())
    }

    private func receive(connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                connection.cancel()
                FileHandle.standardError.write(Data("wdm-web: receive error: \(error)\n".utf8))
                return
            }
            var buffer = accumulated
            if let data { buffer.append(data) }
            switch self.tryHandle(buffer: buffer, connection: connection) {
            case .handled:
                return
            case .needsMore:
                if isComplete {
                    connection.cancel()
                } else {
                    self.receive(connection: connection, accumulated: buffer)
                }
            }
        }
    }

    private enum HandleOutcome { case handled, needsMore }

    private func tryHandle(buffer: Data, connection: NWConnection) -> HandleOutcome {
        let request: WDMWebRequest
        do {
            request = try WDMWebRequestParser.parse(buffer)
        } catch WDMWebRequestError.incomplete {
            return .needsMore
        } catch {
            sendAndClose(WDMWebResponse.error(status: 400, message: "\(error)"), on: connection)
            return .handled
        }
        if !bodyComplete(request) { return .needsMore }
        let response = dispatch(request: request)
        sendAndClose(response, on: connection)
        return .handled
    }

    private func bodyComplete(_ request: WDMWebRequest) -> Bool {
        guard let lengthStr = request.headers["content-length"], let length = Int(lengthStr) else {
            return true
        }
        return request.body.count >= length
    }

    private func dispatch(request: WDMWebRequest) -> WDMWebResponse {
        guard let match = router.match(method: request.method, path: request.path) else {
            return WDMWebResponse.error(status: 404, message: "no route for \(request.method) \(request.path)")
        }
        do {
            return try match.route.handler(request, match.pathParams, deps)
        } catch let error as WDMError {
            return WDMWebResponse.error(
                status: WDMWebHandlerSupport.httpStatus(for: error),
                message: error.message
            )
        } catch {
            return WDMWebResponse.error(status: 500, message: "\(error)")
        }
    }

    private func sendAndClose(_ response: WDMWebResponse, on connection: NWConnection) {
        connection.send(content: response.encode(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

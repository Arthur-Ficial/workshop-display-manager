import Foundation
import Network

/// HTTP server hosting a `RemoteControllable`. Mirrors `WDMWebServer`'s shape.
/// Binds 127.0.0.1 only — local control surface, no remote network access.
public final class RemoteControlServer: @unchecked Sendable {
    public let port: UInt16
    private let listener: NWListener
    private let target: RemoteControllable
    private let version: String
    private let queue = DispatchQueue(label: "wdm.remote.server")

    public init(port: UInt16, target: RemoteControllable, version: String = "wdm-remote/0.1") throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        if let tcp = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
        }
        let listenPort = NWEndpoint.Port(rawValue: port) ?? .any
        self.listener = try NWListener(using: parameters, on: listenPort)
        self.target = target
        self.version = version
        self.port = port
    }

    public func runAsync() {
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        let sem = readySemaphore
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready, .failed, .cancelled:
                sem.signal()
            default:
                break
            }
        }
        listener.start(queue: queue)
    }

    public func stop() { listener.cancel() }

    private let readySemaphore = DispatchSemaphore(value: 0)

    /// Blocks until the listener reaches `.ready` (or times out) and returns
    /// the actual bound port — necessary when constructed with `port: 0`.
    public func resolvedPort(timeout: TimeInterval = 5.0) -> UInt16? {
        _ = readySemaphore.wait(timeout: .now() + timeout)
        return listener.port?.rawValue
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn: conn, accumulated: Data())
    }

    private func receive(conn: NWConnection, accumulated: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            if error != nil { conn.cancel(); return }
            var buffer = accumulated
            if let data { buffer.append(data) }
            switch self.tryHandle(buffer: buffer, conn: conn) {
            case .handled: return
            case .needsMore:
                if isComplete { conn.cancel() }
                else { self.receive(conn: conn, accumulated: buffer) }
            }
        }
    }

    private enum Outcome { case handled, needsMore }

    private func tryHandle(buffer: Data, conn: NWConnection) -> Outcome {
        let request: RemoteRequest
        do { request = try RemoteRequestParser.parse(buffer) }
        catch RemoteRequestError.incomplete { return .needsMore }
        catch {
            sendAndClose(.error(status: 400, message: "\(error)"), on: conn)
            return .handled
        }
        if !bodyComplete(request) { return .needsMore }
        let response = RemoteControlRoutes.dispatch(
            request: request, target: target, version: version
        )
        sendAndClose(response, on: conn)
        return .handled
    }

    private func bodyComplete(_ r: RemoteRequest) -> Bool {
        guard let lengthStr = r.headers["content-length"], let length = Int(lengthStr) else {
            return true
        }
        return r.body.count >= length
    }

    private func sendAndClose(_ response: RemoteResponse, on conn: NWConnection) {
        conn.send(content: response.encode(), completion: .contentProcessed { _ in
            conn.cancel()
        })
    }
}

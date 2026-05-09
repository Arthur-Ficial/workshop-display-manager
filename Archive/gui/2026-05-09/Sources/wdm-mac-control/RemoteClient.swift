import Foundation

/// Tiny URLSession wrapper so subcommands stay declarative. Synchronous via
/// a semaphore so we can stay in main.swift's top-level imperative style.
struct RemoteClient {
    let port: UInt16
    let baseHost: String

    init(port: UInt16, host: String = "127.0.0.1") {
        self.port = port; self.baseHost = host
    }

    func get(_ path: String) throws -> Data {
        let url = URL(string: "http://\(baseHost):\(port)\(path)")!
        return try perform(URLRequest(url: url))
    }

    func post(_ path: String, body: Data) throws -> Data {
        let url = URL(string: "http://\(baseHost):\(port)\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return try perform(req)
    }

    private func perform(_ req: URLRequest) throws -> Data {
        let sem = DispatchSemaphore(value: 0)
        let box = ResultBox()
        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error { box.set(.failure(error)) }
            else { box.set(.success(data ?? Data())) }
            sem.signal()
        }.resume()
        sem.wait()
        return try box.get()
    }
}

private final class ResultBox: @unchecked Sendable {
    private var value: Result<Data, Error>?
    private let lock = NSLock()
    func set(_ r: Result<Data, Error>) { lock.lock(); value = r; lock.unlock() }
    func get() throws -> Data {
        lock.lock(); defer { lock.unlock() }
        return try value!.get()
    }
}

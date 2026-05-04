import Foundation

/// Minimal HTTP/1.1 parser. Single request, complete buffer in.
/// Local-only, one short request per connection — same scope as `WDMWeb`.
public enum RemoteRequestParser {
    public static func parse(_ data: Data) throws -> RemoteRequest {
        guard let separator = headerEnd(in: data) else { throw RemoteRequestError.incomplete }
        let head = data[..<separator.lowerBound]
        let body = data[separator.upperBound...]
        guard let headText = String(data: head, encoding: .utf8) else {
            throw RemoteRequestError.malformed("non-utf8 header")
        }
        let lines = headText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else {
            throw RemoteRequestError.malformed("missing request line")
        }
        let parts = requestLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count == 3 else {
            throw RemoteRequestError.malformed("bad request line: \(requestLine)")
        }
        return RemoteRequest(
            method: String(parts[0]),
            path: String(parts[1]),
            headers: parseHeaders(lines.dropFirst()),
            body: Data(body)
        )
    }

    private static func headerEnd(in data: Data) -> Range<Data.Index>? {
        data.range(of: Data("\r\n\r\n".utf8))
    }

    private static func parseHeaders<S: Sequence>(_ lines: S) -> [String: String]
    where S.Element == Substring {
        var out: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            out[name] = value
        }
        return out
    }
}

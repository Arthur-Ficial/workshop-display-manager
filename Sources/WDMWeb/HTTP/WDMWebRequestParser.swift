import Foundation

/// Minimal HTTP/1.1 request parser. Single request, complete buffer in.
/// Bigger surface (chunked, pipelining, keep-alive) is out of scope — wdm-web
/// is local-only with one short request per connection.
public enum WDMWebRequestParser {
    public static let maxBodyBytes = 16 * 1024 * 1024 // 16 MiB

    public static func parse(_ data: Data) throws -> WDMWebRequest {
        guard let separator = headerEnd(in: data) else {
            throw WDMWebRequestError.incomplete
        }
        let head = data[..<separator.lowerBound]
        let body = data[separator.upperBound...]
        guard let headText = String(data: head, encoding: .utf8) else {
            throw WDMWebRequestError.malformed("non-utf8 header")
        }
        let lines = headText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else {
            throw WDMWebRequestError.malformed("missing request line")
        }
        let parts = requestLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count == 3 else {
            throw WDMWebRequestError.malformed("bad request line: \(requestLine)")
        }
        let headers = parseHeaders(lines.dropFirst())
        return WDMWebRequest(
            method: String(parts[0]),
            path: String(parts[1]),
            headers: headers,
            body: Data(body)
        )
    }

    private static func headerEnd(in data: Data) -> Range<Data.Index>? {
        let separator = Data("\r\n\r\n".utf8)
        return data.range(of: separator)
    }

    private static func parseHeaders<S: Sequence>(_ lines: S) -> [String: String]
    where S.Element == Substring {
        var out: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).lowercased()
            var value = String(line[line.index(after: colon)...])
            value = value.trimmingCharacters(in: .whitespaces)
            out[name] = value
        }
        return out
    }
}

import Foundation
import Testing
@testable import WDMWeb

@Suite("WDMWebRequestParser")
struct WDMWebRequestParserTests {
    @Test("parses a GET line and an empty body")
    func parseGet() throws {
        let raw = "GET /displays HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = try WDMWebRequestParser.parse(Data(raw.utf8))
        #expect(request.method == "GET")
        #expect(request.path == "/displays")
        #expect(request.body.isEmpty)
    }

    @Test("parses a POST line with JSON body")
    func parsePost() throws {
        let body = #"{"alias":"2"}"#
        let raw = "POST /displays/main HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let request = try WDMWebRequestParser.parse(Data(raw.utf8))
        #expect(request.method == "POST")
        #expect(request.path == "/displays/main")
        #expect(String(decoding: request.body, as: UTF8.self) == body)
    }

    @Test("malformed request line throws")
    func malformed() {
        #expect(throws: Error.self) {
            _ = try WDMWebRequestParser.parse(Data("garbage".utf8))
        }
    }
}

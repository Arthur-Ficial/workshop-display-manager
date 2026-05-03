import Foundation
import Testing
import WDMKit
@testable import WDMWeb

@Suite("WDMWeb end-to-end smoke (real HTTP, fixture provider)")
struct WDMWebSmokeTests {
    @Test("GET /displays against the fixture returns the same data as the controller")
    func roundTripList() async throws {
        let (server, port, deps) = try makeServer()
        defer { server.stop() }
        try await Task.sleep(nanoseconds: 100_000_000)

        let url = URL(string: "http://127.0.0.1:\(port)/displays")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let http = response as! HTTPURLResponse
        #expect(http.statusCode == 200)

        // Decode the expected payload via the controller and compare.
        let expected = try deps.controller.list()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let expectedData = try encoder.encode(expected)
        #expect(data == expectedData)
    }

    @Test("POST /displays/{alias}/main switches main display via the fixture")
    func roundTripSetMain() async throws {
        let (server, port, deps) = try makeServer()
        defer { server.stop() }
        try await Task.sleep(nanoseconds: 100_000_000)

        let url = URL(string: "http://127.0.0.1:\(port)/displays/2/main")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = Data("{}".utf8)
        let (_, response) = try await URLSession.shared.data(for: req)
        let http = response as! HTTPURLResponse
        #expect(http.statusCode == 200)

        let snap = try deps.provider.snapshot()
        #expect(snap.main?.id == 2)
    }

    @Test("GET /displays/{alias} on unknown returns 404 with typed error JSON")
    func notFound() async throws {
        let (server, port, _) = try makeServer()
        defer { server.stop() }
        try await Task.sleep(nanoseconds: 100_000_000)

        let url = URL(string: "http://127.0.0.1:\(port)/displays/999")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let http = response as! HTTPURLResponse
        #expect(http.statusCode == 404)
        let payload = String(decoding: data, as: UTF8.self)
        #expect(payload.contains("error"))
    }

    private func makeServer() throws -> (WDMWebServer, UInt16, WDMWebDeps) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wdm-web-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fixture = dir.appendingPathComponent("fixture.json")
        try Self.fixtureJSON.write(to: fixture, atomically: true, encoding: .utf8)
        let env = ["WDM_TEST_FIXTURE": fixture.path,
                   "WDM_PROFILES_DIR": dir.appendingPathComponent("profiles").path]
        let deps = try WDMWebControllerFactory.make(env: env)
        let port = try findFreePort()
        let server = try WDMWebServer(host: "127.0.0.1", port: port, deps: deps)
        server.runAsync()
        return (server, port, deps)
    }

    private func findFreePort() throws -> UInt16 {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        let bound = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        defer { close(socketFD) }
        guard bound == 0 else { throw NSError(domain: "bind", code: -1) }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let got = withUnsafeMutablePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socketFD, $0, &len)
            }
        }
        guard got == 0 else { throw NSError(domain: "getsockname", code: -1) }
        return UInt16(bigEndian: addr.sin_port)
    }

    private static let fixtureJSON = """
    {
      "snapshot": {
        "createdAt": 1700000000,
        "displays": [
          { "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
            "origin": { "x": 0, "y": 0 }, "rotationDegrees": 0 },
          { "id": 2, "name": "Projector", "isMain": false, "isOnline": true,
            "mirrorSource": null,
            "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
            "origin": { "x": 2560, "y": 0 }, "rotationDegrees": 0 }
        ]
      },
      "availableModes": {
        "1": [{ "width": 2560, "height": 1664, "refreshHz": 60 }],
        "2": [{ "width": 1920, "height": 1080, "refreshHz": 60 }]
      }
    }
    """
}

import Testing
import Foundation
@testable import WDMCore

@Suite("Flip")
struct FlipTests {

    @Test("cases cover none / horizontal / vertical / both")
    func cases() {
        let all: [Flip] = [.none, .horizontal, .vertical, .both]
        #expect(all.count == 4)
    }

    @Test("rawValue is the canonical CLI token")
    func rawValues() {
        #expect(Flip.none.rawValue == "none")
        #expect(Flip.horizontal.rawValue == "horizontal")
        #expect(Flip.vertical.rawValue == "vertical")
        #expect(Flip.both.rawValue == "both")
    }

    @Test("parse accepts canonical tokens and short aliases")
    func parseTokens() {
        // Use fully-qualified Flip.none on the RHS to avoid resolving to Optional.none.
        #expect(Flip.parse("none") == Flip.none)
        #expect(Flip.parse("horizontal") == .horizontal)
        #expect(Flip.parse("vertical") == .vertical)
        #expect(Flip.parse("both") == .both)
        // short aliases — sharper at the CLI
        #expect(Flip.parse("h") == .horizontal)
        #expect(Flip.parse("v") == .vertical)
        #expect(Flip.parse("hv") == .both)
        #expect(Flip.parse("vh") == .both)
        #expect(Flip.parse("off") == Flip.none)
    }

    @Test("parse rejects unknown tokens")
    func parseRejects() {
        #expect(Flip.parse("upside-down") == nil)
        #expect(Flip.parse("") == nil)
        #expect(Flip.parse("flipx") == nil)
    }

    @Test("invertsX / invertsY decompose the value")
    func axisDecomposition() {
        #expect(Flip.none.invertsX == false)
        #expect(Flip.none.invertsY == false)
        #expect(Flip.horizontal.invertsX == true)
        #expect(Flip.horizontal.invertsY == false)
        #expect(Flip.vertical.invertsX == false)
        #expect(Flip.vertical.invertsY == true)
        #expect(Flip.both.invertsX == true)
        #expect(Flip.both.invertsY == true)
    }

    @Test("Codable round-trips through JSON")
    func codable() throws {
        for f in [Flip.none, .horizontal, .vertical, .both] {
            let data = try JSONEncoder().encode(["flip": f])
            let decoded = try JSONDecoder().decode([String: Flip].self, from: data)
            #expect(decoded["flip"] == f)
        }
    }
}

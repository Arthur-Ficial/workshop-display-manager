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

    @Test("toggling: H and V combine to .both, click again clears")
    func togglingCombines() {
        // From .none, clicking H and V are independent:
        #expect(Flip.none.toggling(clicked: .horizontal) == .horizontal)
        #expect(Flip.none.toggling(clicked: .vertical) == .vertical)
        // Combine: H on top of V (or V on top of H) → .both.
        #expect(Flip.horizontal.toggling(clicked: .vertical) == .both)
        #expect(Flip.vertical.toggling(clicked: .horizontal) == .both)
        // From .both, clicking H clears H (leaving V); clicking V clears V.
        #expect(Flip.both.toggling(clicked: .horizontal) == .vertical)
        #expect(Flip.both.toggling(clicked: .vertical) == .horizontal)
        // Double-click clears the same axis.
        #expect(Flip.horizontal.toggling(clicked: .horizontal) == Flip.none)
        #expect(Flip.vertical.toggling(clicked: .vertical) == Flip.none)
        // "—" always clears.
        #expect(Flip.both.toggling(clicked: .none) == Flip.none)
        #expect(Flip.horizontal.toggling(clicked: .none) == Flip.none)
        #expect(Flip.vertical.toggling(clicked: .none) == Flip.none)
        #expect(Flip.none.toggling(clicked: .none) == Flip.none)
    }

    @Test("hasAxis: H lights for horizontal AND both; V lights for vertical AND both")
    func hasAxisLighting() {
        // "—" lights only when nothing is flipped.
        #expect(Flip.none.hasAxis(Flip.none))
        #expect(!Flip.horizontal.hasAxis(Flip.none))
        #expect(!Flip.vertical.hasAxis(Flip.none))
        #expect(!Flip.both.hasAxis(Flip.none))
        // Flip H lights for horizontal and both.
        #expect(!Flip.none.hasAxis(.horizontal))
        #expect(Flip.horizontal.hasAxis(.horizontal))
        #expect(!Flip.vertical.hasAxis(.horizontal))
        #expect(Flip.both.hasAxis(.horizontal))
        // Flip V lights for vertical and both.
        #expect(!Flip.none.hasAxis(.vertical))
        #expect(!Flip.horizontal.hasAxis(.vertical))
        #expect(Flip.vertical.hasAxis(.vertical))
        #expect(Flip.both.hasAxis(.vertical))
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

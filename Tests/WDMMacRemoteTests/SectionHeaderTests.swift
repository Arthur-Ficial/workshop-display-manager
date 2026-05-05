import Testing
import SwiftUI
@testable import WDMMac

/// SectionHeader's count-chip rule: nil → no chip, 0 → no chip,
/// >0 → chip. Pinned via the public `showsCountChip(_:)` predicate
/// so any future regression flips a test here, not just visual debt.
@Suite("SectionHeader.showsCountChip")
struct SectionHeaderShowsCountChipTests {
    @Test("nil count → no chip")
    func nilHidesChip() {
        #expect(SectionHeader<EmptyView>.showsCountChip(nil) == false)
    }

    @Test("count == 0 → no chip (empty-state hint already communicates zero)")
    func zeroHidesChip() {
        #expect(SectionHeader<EmptyView>.showsCountChip(0) == false)
    }

    @Test("count == 1 → chip visible")
    func oneShowsChip() {
        #expect(SectionHeader<EmptyView>.showsCountChip(1) == true)
    }

    @Test("count == 7 → chip visible")
    func sevenShowsChip() {
        #expect(SectionHeader<EmptyView>.showsCountChip(7) == true)
    }
}

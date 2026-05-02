import Testing
import Foundation
import CoreGraphics
@testable import WDMCore
@testable import WDMSystem

@Suite("CGDisplayEventStream — flag translation (pure)")
struct CGEventStreamTranslateTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func raw(_ flags: CGDisplayChangeSummaryFlags...) -> UInt32 {
        flags.reduce(UInt32(0)) { $0 | $1.rawValue }
    }

    @Test("skips callbacks whose only flag is BeginConfiguration")
    func skipsBegin() {
        let evts = CGDisplayEventStream.translate(
            displayID: 1, flags: raw(.beginConfigurationFlag), now: now
        )
        #expect(evts.isEmpty)
    }

    @Test("skips any callback with the BeginConfiguration flag set")
    func skipsBeginEvenWithOthers() {
        // CG fires the callback twice; only the final (without begin) carries the real flags.
        let evts = CGDisplayEventStream.translate(
            displayID: 1, flags: raw(.beginConfigurationFlag, .addFlag), now: now
        )
        #expect(evts.isEmpty)
    }

    @Test("AddFlag → .added")
    func add() {
        let evts = CGDisplayEventStream.translate(
            displayID: 7, flags: raw(.addFlag), now: now
        )
        #expect(evts == [DisplayEvent(timestamp: now, kind: .added, displayID: 7)])
    }

    @Test("EnabledFlag → .added")
    func enabledMapsToAdded() {
        let evts = CGDisplayEventStream.translate(
            displayID: 7, flags: raw(.enabledFlag), now: now
        )
        #expect(evts.map(\DisplayEvent.kind) == [.added])
    }

    @Test("RemoveFlag → .removed")
    func remove() {
        let evts = CGDisplayEventStream.translate(
            displayID: 8, flags: raw(.removeFlag), now: now
        )
        #expect(evts == [DisplayEvent(timestamp: now, kind: .removed, displayID: 8)])
    }

    @Test("DisabledFlag → .removed")
    func disabledMapsToRemoved() {
        let evts = CGDisplayEventStream.translate(
            displayID: 8, flags: raw(.disabledFlag), now: now
        )
        #expect(evts.map(\DisplayEvent.kind) == [.removed])
    }

    @Test("SetMainFlag → .mainChanged")
    func mainChanged() {
        let evts = CGDisplayEventStream.translate(
            displayID: 1, flags: raw(.setMainFlag), now: now
        )
        #expect(evts.map(\DisplayEvent.kind) == [.mainChanged])
    }

    @Test("SetModeFlag → .modeChanged")
    func modeChanged() {
        let evts = CGDisplayEventStream.translate(
            displayID: 1, flags: raw(.setModeFlag), now: now
        )
        #expect(evts.map(\DisplayEvent.kind) == [.modeChanged])
    }

    @Test("MovedFlag → .moved")
    func moved() {
        let evts = CGDisplayEventStream.translate(
            displayID: 1, flags: raw(.movedFlag), now: now
        )
        #expect(evts.map(\DisplayEvent.kind) == [.moved])
    }

    @Test("DesktopShapeChangedFlag → .moved")
    func desktopShape() {
        let evts = CGDisplayEventStream.translate(
            displayID: 1, flags: raw(.desktopShapeChangedFlag), now: now
        )
        #expect(evts.map(\DisplayEvent.kind) == [.moved])
    }

    @Test("MirrorFlag → .mirrorChanged")
    func mirror() {
        let evts = CGDisplayEventStream.translate(
            displayID: 1, flags: raw(.mirrorFlag), now: now
        )
        #expect(evts.map(\DisplayEvent.kind) == [.mirrorChanged])
    }

    @Test("UnMirrorFlag → .mirrorChanged")
    func unmirror() {
        let evts = CGDisplayEventStream.translate(
            displayID: 1, flags: raw(.unMirrorFlag), now: now
        )
        #expect(evts.map(\DisplayEvent.kind) == [.mirrorChanged])
    }

    @Test("combined flags emit one DisplayEvent per logical kind")
    func combined() {
        let kinds = CGDisplayEventStream.translate(
            displayID: 5, flags: raw(.addFlag, .setModeFlag, .movedFlag), now: now
        ).map(\DisplayEvent.kind)
        #expect(kinds.contains(.added))
        #expect(kinds.contains(.modeChanged))
        #expect(kinds.contains(.moved))
        #expect(kinds.count == 3)
    }

    @Test("zero flags → no events")
    func zeroFlags() {
        #expect(CGDisplayEventStream.translate(displayID: 1, flags: 0, now: now).isEmpty)
    }
}

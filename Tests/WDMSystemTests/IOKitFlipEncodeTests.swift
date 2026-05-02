import Testing
import Foundation
@testable import WDMCore
@testable import WDMSystem

@Suite("IOKitFlip — transform encoding (pure)")
struct IOKitFlipEncodeTests {

    // No rotation, plain flips.
    @Test("no rotation, no flip → 0x00")
    func r0_none() { #expect(IOKitFlip.encodeTransform(rotationDegrees: 0, flip: .none) == 0x00) }

    @Test("no rotation, horizontal flip → kIOScaleInvertX (0x20)")
    func r0_h() { #expect(IOKitFlip.encodeTransform(rotationDegrees: 0, flip: .horizontal) == 0x20) }

    @Test("no rotation, vertical flip → kIOScaleInvertY (0x40)")
    func r0_v() { #expect(IOKitFlip.encodeTransform(rotationDegrees: 0, flip: .vertical) == 0x40) }

    @Test("no rotation, both → kIOScaleInvertX | kIOScaleInvertY (0x60)")
    func r0_both() { #expect(IOKitFlip.encodeTransform(rotationDegrees: 0, flip: .both) == 0x60) }

    // Rotation alone matches kIOScaleRotateNN bit patterns.
    @Test("rotate 90, no flip → 0x30 (SwapAxes | InvertX)")
    func r90() { #expect(IOKitFlip.encodeTransform(rotationDegrees: 90, flip: .none) == 0x30) }

    @Test("rotate 180, no flip → 0x60 (InvertX | InvertY)")
    func r180() { #expect(IOKitFlip.encodeTransform(rotationDegrees: 180, flip: .none) == 0x60) }

    @Test("rotate 270, no flip → 0x50 (SwapAxes | InvertY)")
    func r270() { #expect(IOKitFlip.encodeTransform(rotationDegrees: 270, flip: .none) == 0x50) }

    // Composed: flip toggles via XOR, so flipping an axis already inverted
    // by rotation cancels it out (the user's mental model is "flip ON TOP of
    // current orientation", not "set absolute X/Y inversion").
    @Test("rotate 180 + horizontal flip cancels InvertX → only InvertY (0x40)")
    func r180_h_cancels() {
        #expect(IOKitFlip.encodeTransform(rotationDegrees: 180, flip: .horizontal) == 0x40)
    }

    @Test("rotate 180 + vertical flip cancels InvertY → only InvertX (0x20)")
    func r180_v_cancels() {
        #expect(IOKitFlip.encodeTransform(rotationDegrees: 180, flip: .vertical) == 0x20)
    }

    @Test("rotate 180 + both flips cancels both → 0x00")
    func r180_both_cancels() {
        #expect(IOKitFlip.encodeTransform(rotationDegrees: 180, flip: .both) == 0x00)
    }

    @Test("rotate 90 + horizontal flip → 0x10 (SwapAxes only)")
    func r90_h() {
        // 0x30 (SwapAxes|InvertX) XOR 0x20 (InvertX) = 0x10 (SwapAxes)
        #expect(IOKitFlip.encodeTransform(rotationDegrees: 90, flip: .horizontal) == 0x10)
    }

    @Test("rotate 270 + vertical flip → 0x10 (SwapAxes only)")
    func r270_v() {
        // 0x50 (SwapAxes|InvertY) XOR 0x40 (InvertY) = 0x10 (SwapAxes)
        #expect(IOKitFlip.encodeTransform(rotationDegrees: 270, flip: .vertical) == 0x10)
    }
}

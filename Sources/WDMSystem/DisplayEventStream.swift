import Foundation
import WDMCore

/// Async source of `DisplayEvent`s. Two implementations exist:
/// `EventStreamFile` for hermetic tests, `CGDisplayEventStream` for real hardware.
public protocol DisplayEventStream: Sendable {
    var events: AsyncThrowingStream<DisplayEvent, Error> { get }
}

extension EventStreamFile: DisplayEventStream {}

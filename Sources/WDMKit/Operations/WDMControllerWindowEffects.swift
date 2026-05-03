import CoreGraphics
import WDMSystem

extension WDMController {
    public func moveWindow(pattern: String, to alias: String, using mover: WindowMover) throws {
        try mapErrors {
            try mover.move(pattern: pattern, displayID: get(alias).id)
        }
    }

    public func focus(_ alias: String, using mover: WindowMover) throws {
        try mapErrors {
            try mover.focus(displayID: get(alias).id)
        }
    }

    public func tileApp(pattern: String, across aliases: [String], using mover: WindowMover) throws {
        try mapErrors {
            let ids = try aliases.map { try get($0).id }
            try mover.tileAcross(pattern: pattern, displayIDs: ids)
        }
    }

    public func screenWindows(_ alias: String, using lister: WindowLister) throws -> [WindowInfo] {
        try mapErrors {
            let display = try get(alias)
            return try lister.windows(onDisplay: bounds(of: display))
        }
    }

    private func bounds(of display: DisplayInfo) -> CGRect {
        CGRect(
            x: display.origin.x,
            y: display.origin.y,
            width: display.currentMode.width,
            height: display.currentMode.height
        )
    }
}

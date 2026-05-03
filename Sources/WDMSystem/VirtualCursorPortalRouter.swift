import CoreGraphics

struct VirtualCursorPortalRouter {
    struct Display: Equatable {
        let id: UInt32
        let bounds: CGRect
    }

    struct Route: Equatable {
        let displayID: UInt32
        let globalPoint: CGPoint
        let localPoint: CGPoint
    }

    let targetDisplayID: UInt32
    var edgeSlop: CGFloat = 1
    var inset: CGFloat = 1

    func route(
        location: CGPoint,
        delta: CGVector,
        displays: [Display]
    ) -> Route? {
        guard let current = display(containing: location, in: displays),
              let target = displays.first(where: { $0.id == targetDisplayID })
        else { return nil }
        let destinations = current.id == targetDisplayID
            ? displays.filter { $0.id != targetDisplayID }
            : [target]
        for destination in destinations {
            if let route = route(from: current, to: destination, location: location, delta: delta) {
                return route
            }
        }
        return nil
    }

    static func sharesEdge(_ a: CGRect, _ b: CGRect) -> Bool {
        let vertical = close(a.maxX, b.minX) || close(b.maxX, a.minX)
        let horizontal = close(a.maxY, b.minY) || close(b.maxY, a.minY)
        return (vertical && overlaps(a.minY, a.maxY, b.minY, b.maxY))
            || (horizontal && overlaps(a.minX, a.maxX, b.minX, b.maxX))
    }

    private func route(
        from source: Display,
        to destination: Display,
        location: CGPoint,
        delta: CGVector
    ) -> Route? {
        let src = source.bounds
        let dst = destination.bounds
        if delta.dx < 0, near(location.x, src.minX), near(src.minX, dst.maxX),
           contains(location.y, src, dst, axis: .y) {
            return route(to: destination, global: CGPoint(x: dst.maxX - inset, y: clampY(location.y, dst)))
        }
        if delta.dx > 0, near(location.x, src.maxX), near(src.maxX, dst.minX),
           contains(location.y, src, dst, axis: .y) {
            return route(to: destination, global: CGPoint(x: dst.minX + inset, y: clampY(location.y, dst)))
        }
        if delta.dy < 0, near(location.y, src.minY), near(src.minY, dst.maxY),
           contains(location.x, src, dst, axis: .x) {
            return route(to: destination, global: CGPoint(x: clampX(location.x, dst), y: dst.maxY - inset))
        }
        if delta.dy > 0, near(location.y, src.maxY), near(src.maxY, dst.minY),
           contains(location.x, src, dst, axis: .x) {
            return route(to: destination, global: CGPoint(x: clampX(location.x, dst), y: dst.minY + inset))
        }
        return nil
    }

    private func display(containing point: CGPoint, in displays: [Display]) -> Display? {
        displays.first { $0.bounds.contains(point) }
    }

    private func route(to display: Display, global: CGPoint) -> Route {
        Route(
            displayID: display.id,
            globalPoint: global,
            localPoint: CGPoint(
                x: global.x - display.bounds.minX,
                y: global.y - display.bounds.minY
            )
        )
    }

    private enum Axis { case x, y }

    private func contains(_ value: CGFloat, _ a: CGRect, _ b: CGRect, axis: Axis) -> Bool {
        switch axis {
        case .x: return value >= max(a.minX, b.minX) && value < min(a.maxX, b.maxX)
        case .y: return value >= max(a.minY, b.minY) && value < min(a.maxY, b.maxY)
        }
    }

    private func near(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) <= edgeSlop
    }

    private func clampX(_ x: CGFloat, _ rect: CGRect) -> CGFloat {
        min(max(x, rect.minX + inset), rect.maxX - inset)
    }

    private func clampY(_ y: CGFloat, _ rect: CGRect) -> CGFloat {
        min(max(y, rect.minY + inset), rect.maxY - inset)
    }

    private static func close(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) <= 1
    }

    private static func overlaps(_ minA: CGFloat, _ maxA: CGFloat, _ minB: CGFloat, _ maxB: CGFloat) -> Bool {
        max(minA, minB) < min(maxA, maxB)
    }
}

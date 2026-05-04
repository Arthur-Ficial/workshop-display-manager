import SwiftUI

/// Two display chassis silhouettes for the Stage canvas — laptop (with
/// hinge + base) and external monitor (with stand + foot). Pure SwiftUI
/// `Shape`s; size driven by the parent's frame.
public enum ChassisKind: Hashable, Sendable {
    case laptop
    case monitor
}

public struct ChassisShape: Shape {
    public let kind: ChassisKind
    public init(kind: ChassisKind) { self.kind = kind }

    public func path(in rect: CGRect) -> Path {
        switch kind {
        case .laptop: laptopPath(in: rect)
        case .monitor: monitorPath(in: rect)
        }
    }

    /// Laptop: rounded screen rectangle taking ~80% of height, centred,
    /// with a thin trapezoidal base below.
    private func laptopPath(in rect: CGRect) -> Path {
        var p = Path()
        let baseH = rect.height * 0.06
        let hinge = rect.height * 0.02
        let screen = CGRect(x: rect.minX, y: rect.minY,
                            width: rect.width,
                            height: rect.height - baseH - hinge)
        p.addRoundedRect(in: screen, cornerSize: CGSize(width: 8, height: 8))
        // base trapezoid
        let baseY = rect.maxY - baseH
        let baseInset = rect.width * 0.06
        p.move(to: CGPoint(x: rect.minX + baseInset * 0.4, y: baseY))
        p.addLine(to: CGPoint(x: rect.maxX - baseInset * 0.4, y: baseY))
        p.addLine(to: CGPoint(x: rect.maxX - baseInset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + baseInset, y: rect.maxY))
        p.closeSubpath()
        return p
    }

    /// External monitor: rounded screen rect ~75% height, vertical neck
    /// (slim rectangle), wide foot at the bottom.
    private func monitorPath(in rect: CGRect) -> Path {
        var p = Path()
        let footH = rect.height * 0.06
        let neckH = rect.height * 0.10
        let footInset = rect.width * 0.30
        let neckInset = rect.width * 0.45
        let screen = CGRect(x: rect.minX, y: rect.minY,
                            width: rect.width,
                            height: rect.height - footH - neckH)
        p.addRoundedRect(in: screen, cornerSize: CGSize(width: 8, height: 8))
        // neck
        let neckY = screen.maxY
        p.addRect(CGRect(x: rect.minX + neckInset, y: neckY,
                         width: rect.width - 2 * neckInset, height: neckH))
        // foot
        let footY = neckY + neckH
        p.addRoundedRect(
            in: CGRect(x: rect.minX + footInset, y: footY,
                       width: rect.width - 2 * footInset, height: footH),
            cornerSize: CGSize(width: 3, height: 3)
        )
        return p
    }
}

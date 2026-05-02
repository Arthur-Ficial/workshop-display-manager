import Foundation

public struct Mode: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let width: Int
    public let height: Int
    public let refreshHz: Double

    public init(width: Int, height: Int, refreshHz: Double) {
        self.width = width
        self.height = height
        self.refreshHz = refreshHz
    }

    public enum ParseError: Error, Equatable, Sendable {
        case missingAt
        case badDimensions
        case nonNumeric
        case nonPositive
    }

    public static func parse(_ s: String) throws -> Mode {
        let parts = s.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw ParseError.missingAt }
        let dims = parts[0].split(separator: "x", omittingEmptySubsequences: false)
        guard dims.count == 2 else { throw ParseError.badDimensions }
        guard let w = Int(dims[0]), let h = Int(dims[1]) else { throw ParseError.nonNumeric }
        guard let hz = Double(parts[1]) else { throw ParseError.nonNumeric }
        guard w > 0, h > 0, hz > 0 else { throw ParseError.nonPositive }
        return Mode(width: w, height: h, refreshHz: hz)
    }

    public var description: String {
        let hzString: String
        if refreshHz.rounded() == refreshHz {
            hzString = String(Int(refreshHz))
        } else {
            hzString = String(format: "%g", refreshHz)
        }
        return "\(width)x\(height)@\(hzString)"
    }
}

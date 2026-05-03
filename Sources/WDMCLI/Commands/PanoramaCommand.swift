import Foundation
import WDMKit

/// Capture every active display + compose a single panoramic PNG arranged
/// horizontally in `provider.snapshot()` order.
public enum PanoramaCommand {
    public static func run(args: [String], deps: CLIDeps) throws -> Int32 {
        guard let outPath = Args.flagString(args, name: "--out"), !outPath.isEmpty else {
            throw WDMError.usage("usage: wdm panorama --out <path>")
        }
        let result = try deps.controller.panorama(
            to: URL(fileURLWithPath: outPath),
            using: deps.screenshotter
        )
        deps.stderr.writeLine(
            "wdm: panorama \(result.displayCount) display(s) → \(result.outputURL.path) " +
            "(\(result.totalWidth)x\(result.height))"
        )
        return ExitCodes.success
    }
}

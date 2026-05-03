import WDMSystem

extension WDMController {
    public func edid(_ alias: String) throws -> EDID {
        try mapErrors {
            try provider.edid(for: resolve(alias))
        }
    }
}

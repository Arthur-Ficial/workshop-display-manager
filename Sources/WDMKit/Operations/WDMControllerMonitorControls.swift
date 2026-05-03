import WDMSystem

extension WDMController {
    public func ddcRead(_ alias: String, vcp: UInt8, using provider: DDCProvider) throws -> UInt16 {
        do {
            return try provider.read(displayID: get(alias).id, vcp: vcp)
        } catch DDCError.unsupported(let id) {
            throw WDMError.ddcUnsupported(id)
        } catch DDCError.ioFailure(let message) {
            throw WDMError.coreGraphicsError(message)
        }
    }

    public func ddcWrite(_ alias: String, vcp: UInt8, value: UInt16, using provider: DDCProvider) throws {
        do {
            try provider.write(displayID: get(alias).id, vcp: vcp, value: value)
        } catch DDCError.unsupported(let id) {
            throw WDMError.ddcUnsupported(id)
        } catch DDCError.ioFailure(let message) {
            throw WDMError.coreGraphicsError(message)
        }
    }

    public func hdr(_ alias: String, using provider: HDRProvider) throws -> Bool? {
        do {
            return try provider.isHDREnabled(displayID: get(alias).id)
        } catch HDRError.unsupported(let id) {
            throw WDMError.modeNotSupported("display \(id) does not support HDR")
        } catch HDRError.ioFailure(let message) {
            throw WDMError.coreGraphicsError(message)
        }
    }

    public func setHDR(_ alias: String, enabled: Bool, using provider: HDRProvider) throws {
        do {
            try provider.setHDR(displayID: get(alias).id, enabled: enabled)
        } catch HDRError.unsupported(let id) {
            throw WDMError.modeNotSupported("display \(id) does not support HDR")
        } catch HDRError.ioFailure(let message) {
            throw WDMError.coreGraphicsError(message)
        }
    }
}

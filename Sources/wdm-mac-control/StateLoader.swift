import Foundation
import WDMRemoteControl

enum StateLoader {
    enum Failure: Error, CustomStringConvertible {
        case missing(URL)
        case decode(Error)
        var description: String {
            switch self {
            case .missing(let u): "no remote state at \(u.path) — is wdm-mac --remote running?"
            case .decode(let e): "could not decode remote state: \(e)"
            }
        }
    }

    static func load(env: [String: String]) throws -> RemoteState {
        let path = RemoteStateWriter.defaultPath(env: env)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw Failure.missing(path)
        }
        do { return try RemoteStateWriter.read(from: path) }
        catch { throw Failure.decode(error) }
    }
}

import Foundation
import WDMMacRemote

let argv = Array(CommandLine.arguments.dropFirst())
let args: MacArgs
do {
    args = try MacArgs.parse(argv)
} catch {
    FileHandle.standardError.write(Data("wdm-mac: \(error)\n\n\(MacArgs.usage)\n".utf8))
    exit(2)
}

if args.headless {
    do { try HeadlessRunner.run(args: args) }
    catch {
        FileHandle.standardError.write(Data("wdm-mac headless: \(error)\n".utf8))
        exit(1)
    }
} else {
    do { try HeadedRunner.run(args: args) }
    catch {
        FileHandle.standardError.write(Data("wdm-mac: \(error)\n".utf8))
        exit(1)
    }
}

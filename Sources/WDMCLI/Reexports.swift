// Re-export the Kit surface so anyone importing WDMCLI sees Kit's public
// symbols (formatters, profile store, output sinks, factories, …) without
// adding a second import line. Tests in WDMCLITests use `@testable import
// WDMCLI` and rely on this; new frontends should `import WDMKit` directly.
@_exported import WDMKit

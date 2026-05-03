import WDMKit

extension CLIDeps {
    var controller: WDMController {
        WDMController(provider: provider, profileStore: profileStore, env: processEnv)
    }
}

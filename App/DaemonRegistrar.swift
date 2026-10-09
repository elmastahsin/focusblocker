import ServiceManagement
import FocusCore

struct DaemonRegistrar {
    private var service: SMAppService { .daemon(plistName: Identifiers.daemonPlistName) }

    var status: SMAppService.Status { service.status }

    func register() throws {
        try service.register()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

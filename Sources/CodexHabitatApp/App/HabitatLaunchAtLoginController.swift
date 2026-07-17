import ServiceManagement

enum HabitatLaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var isRequested: Bool {
        self == .enabled || self == .requiresApproval
    }
}

@MainActor
protocol HabitatLaunchAtLoginControlling: AnyObject {
    var status: HabitatLaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws -> HabitatLaunchAtLoginStatus
    func openSystemSettings()
}

@MainActor
final class SystemHabitatLaunchAtLoginController: HabitatLaunchAtLoginControlling {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var status: HabitatLaunchAtLoginStatus {
        switch service.status {
        case .enabled:
            .enabled
        case .notRegistered:
            .disabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws -> HabitatLaunchAtLoginStatus {
        if enabled {
            if service.status == .notRegistered {
                try service.register()
            }
        } else if service.status != .notRegistered {
            try service.unregister()
        }
        return status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
final class InMemoryHabitatLaunchAtLoginController: HabitatLaunchAtLoginControlling {
    private(set) var status: HabitatLaunchAtLoginStatus = .disabled

    func setEnabled(_ enabled: Bool) throws -> HabitatLaunchAtLoginStatus {
        status = enabled ? .enabled : .disabled
        return status
    }

    func openSystemSettings() {}
}

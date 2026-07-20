import Foundation

enum ThemeBridgePresentedErrorCode: String, Equatable, Sendable {
    case listenerUnavailable
    case targetUnavailable
    case runtimeUnavailable
    case domHealthRejected
    case processRejected
    case unsupportedVersion
    case unknown
}

enum ThemeBridgeErrorPresenter {
    static func line(for error: any Error) -> String {
        "theme-bridge: code=\(code(for: error).rawValue)"
    }

    private static func code(for error: any Error) -> ThemeBridgePresentedErrorCode {
        if let error = error as? ThemeBridgeCoordinatorError {
            switch error {
            case .listenerNotOwned:
                return .listenerUnavailable
            case .targetUnavailable:
                return .targetUnavailable
            case .runtimeUnavailable:
                return .runtimeUnavailable
            case .healthCheckFailed:
                return .domHealthRejected
            case .unsupportedCodexVersion:
                return .unsupportedVersion
            case .activeSessionMismatch, .authorizationRequired, .staleSession:
                return .processRejected
            case .restorationFailed:
                return .unknown
            }
        }
        if error is CDPTargetValidationError
            || error is CodexBundleVerificationError
            || error is ThemeSessionError
            || error is CodexRestartError
        {
            return .processRejected
        }
        if error is LoopbackListenerError {
            return .listenerUnavailable
        }
        return .unknown
    }
}

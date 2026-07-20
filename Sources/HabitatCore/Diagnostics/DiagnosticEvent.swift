import Foundation

public enum DiagnosticModule: String, Codable, CaseIterable, Sendable {
    case application
    case codexConnector
    case resourceLibrary
    case themeBridge
    case updater
}

public enum DiagnosticCode: String, Codable, CaseIterable, Sendable {
    case started
    case connectionAvailable
    case connectionUnavailable
    case protocolMismatch
    case resourcesValidated
    case resourcesRejected
    case themeApplied
    case themeApplyFailed
    case themeListenerUnavailable
    case themeTargetUnavailable
    case themeRuntimeUnavailable
    case themeLayoutRejected
    case themeProcessRejected
    case themeUnsupportedVersion
    case themeWatchFailed
    case themeRestored
    case themeRestoreFailed
    case diagnosticsExported
    case localCacheCleared
    case updateCheckFailed
}

public struct DiagnosticEvent: Codable, Equatable, Sendable {
    public let module: DiagnosticModule
    public let code: DiagnosticCode
    public let appVersion: String?
    public let codexVersion: String?
    public let timestamp: Date

    public init(
        module: DiagnosticModule,
        code: DiagnosticCode,
        appVersion: String? = nil,
        codexVersion: String? = nil,
        timestamp: Date = Date()
    ) {
        self.module = module
        self.code = code
        self.appVersion = Self.sanitizedVersion(appVersion)
        self.codexVersion = Self.sanitizedVersion(codexVersion)
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case module, code, appVersion, codexVersion, timestamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            module: try container.decode(DiagnosticModule.self, forKey: .module),
            code: try container.decode(DiagnosticCode.self, forKey: .code),
            appVersion: try container.decodeIfPresent(String.self, forKey: .appVersion),
            codexVersion: try container.decodeIfPresent(String.self, forKey: .codexVersion),
            timestamp: try container.decode(Date.self, forKey: .timestamp)
        )
    }

    static func ordered(_ lhs: DiagnosticEvent, before rhs: DiagnosticEvent) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        if lhs.module.rawValue != rhs.module.rawValue {
            return lhs.module.rawValue < rhs.module.rawValue
        }
        if lhs.code.rawValue != rhs.code.rawValue {
            return lhs.code.rawValue < rhs.code.rawValue
        }
        if lhs.appVersion != rhs.appVersion {
            return (lhs.appVersion ?? "") < (rhs.appVersion ?? "")
        }
        return (lhs.codexVersion ?? "") < (rhs.codexVersion ?? "")
    }

    private static func sanitizedVersion(_ value: String?) -> String? {
        guard let value,
              value.range(
                of: "^[0-9]{1,6}(\\.[0-9]{1,12}){1,3}(-[A-Za-z0-9.]{1,24})?(\\+[A-Za-z0-9.]{1,24})?$",
                options: .regularExpression
              ) != nil
        else {
            return nil
        }
        return value
    }
}

public enum DiagnosticRecovery {
    public static let officialAppearanceTitle = "Restore Official Appearance"
    public static let themeBridgeExecutable = "CodexHabitatThemeBridge"
    public static let themeBridgeArguments = ["restore"]
}

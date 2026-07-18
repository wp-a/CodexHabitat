import Foundation

struct CDPTarget: Codable, Equatable, Sendable {
    let id: String
    let type: String
    let title: String
    let url: URL
    let webSocketDebuggerURL: URL

    init(
        id: String,
        type: String,
        title: String,
        url: URL,
        webSocketDebuggerURL: URL
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.url = url
        self.webSocketDebuggerURL = webSocketDebuggerURL
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, title, url
        case webSocketDebuggerURL = "webSocketDebuggerUrl"
    }
}

enum CDPTargetValidationError: Error, Equatable, Sendable {
    case invalidIdentifier
    case unsupportedTargetType(String)
    case nonLoopbackURL
    case wrongPort
    case credentialsNotAllowed
    case queryOrFragmentNotAllowed
    case invalidDevToolsPath
    case nonAppPage
    case invalidListEndpoint
}

enum CDPTargetClassification: Equatable, Sendable {
    case mainPage
    case officialAuxiliaryPage
}

struct CDPTargetValidator: Sendable {
    let port: UInt16

    func validate(_ target: CDPTarget) throws -> CDPTarget {
        guard try classification(of: target) == .mainPage else {
            throw CDPTargetValidationError.nonAppPage
        }
        return target
    }

    func classification(of target: CDPTarget) throws -> CDPTargetClassification {
        try validateDebuggerEndpoint(target)

        let pageURL = target.url
        guard pageURL.user == nil, pageURL.password == nil,
              pageURL.fragment == nil
        else {
            throw CDPTargetValidationError.queryOrFragmentNotAllowed
        }
        guard pageURL.scheme?.lowercased() == "app",
              ["-", "codex"].contains(pageURL.host?.lowercased() ?? "")
        else {
            throw CDPTargetValidationError.nonAppPage
        }
        if pageURL.path == "/avatar-overlay-composition-surface.html" {
            try validatePetSurfaceQuery(pageURL)
            return .officialAuxiliaryPage
        }
        guard pageURL.path == "/index.html" else {
            throw CDPTargetValidationError.nonAppPage
        }
        let initialRoute = try validateIndexPageQuery(pageURL)
        return initialRoute.map(Self.isOfficialAuxiliaryRoute) == true
            ? .officialAuxiliaryPage
            : .mainPage
    }

    private func validateDebuggerEndpoint(_ target: CDPTarget) throws {
        guard target.id.range(
            of: "^[A-Za-z0-9._-]{1,256}$",
            options: .regularExpression
        ) != nil else {
            throw CDPTargetValidationError.invalidIdentifier
        }
        guard target.type == "page" else {
            throw CDPTargetValidationError.unsupportedTargetType(target.type)
        }
        let socketURL = target.webSocketDebuggerURL
        guard socketURL.user == nil, socketURL.password == nil else {
            throw CDPTargetValidationError.credentialsNotAllowed
        }
        guard socketURL.query == nil, socketURL.fragment == nil else {
            throw CDPTargetValidationError.queryOrFragmentNotAllowed
        }
        guard socketURL.scheme?.lowercased() == "ws",
              socketURL.host?.lowercased() == "127.0.0.1"
        else {
            throw CDPTargetValidationError.nonLoopbackURL
        }
        guard socketURL.port == Int(port) else {
            throw CDPTargetValidationError.wrongPort
        }
        guard socketURL.path == "/devtools/page/\(target.id)" else {
            throw CDPTargetValidationError.invalidDevToolsPath
        }
    }

    private func validatePetSurfaceQuery(_ url: URL) throws {
        guard let items = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems,
              items.count == 1,
              items[0].name == "surfaceId",
              let value = items[0].value,
              value.range(
                of: "^[A-Za-z0-9._-]{1,256}$",
                options: .regularExpression
              ) != nil
        else {
            throw CDPTargetValidationError.queryOrFragmentNotAllowed
        }
    }

    private func validateIndexPageQuery(_ url: URL) throws -> String? {
        guard let items = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems else {
            return nil
        }
        var seen: Set<String> = []
        var initialRoute: String?
        for item in items {
            guard seen.insert(item.name).inserted else {
                throw CDPTargetValidationError.queryOrFragmentNotAllowed
            }
            switch item.name {
            case "initialRoute":
                guard let value = item.value,
                      value.hasPrefix("/"),
                      value.utf8.count <= 4_096
                else {
                    throw CDPTargetValidationError.queryOrFragmentNotAllowed
                }
                initialRoute = value
            case "mcpAppSandboxDevtools":
                guard item.value == "1" else {
                    throw CDPTargetValidationError.queryOrFragmentNotAllowed
                }
            default:
                throw CDPTargetValidationError.queryOrFragmentNotAllowed
            }
        }
        return initialRoute
    }

    private static func isOfficialAuxiliaryRoute(_ route: String) -> Bool {
        route == "/avatar-overlay"
            || route == "/debug"
            || route == "/global-dictation"
            || route == "/hotkey-window"
            || route.hasPrefix("/hotkey-window/")
            || route == "/chatgpt/quick-chat"
            || route.hasPrefix("/chatgpt/quick-chat-")
    }

    func validateListEndpoint(_ url: URL) throws -> URL {
        guard url.scheme?.lowercased() == "http",
              url.host?.lowercased() == "127.0.0.1",
              url.port == Int(port),
              url.path == "/json/list",
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil
        else {
            throw CDPTargetValidationError.invalidListEndpoint
        }
        return url
    }
}

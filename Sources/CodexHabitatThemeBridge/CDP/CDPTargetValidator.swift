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

struct CDPTargetValidator: Sendable {
    let port: UInt16

    func validate(_ target: CDPTarget) throws -> CDPTarget {
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

        let pageURL = target.url
        guard pageURL.user == nil, pageURL.password == nil,
              pageURL.query == nil, pageURL.fragment == nil
        else {
            throw CDPTargetValidationError.queryOrFragmentNotAllowed
        }
        guard pageURL.scheme?.lowercased() == "app" else {
            throw CDPTargetValidationError.nonAppPage
        }
        return target
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

import CryptoKit
import Foundation
import Security

public struct CodexEventSanitizer: Sendable {
    private let salt: Data

    public init(salt: Data) {
        self.salt = salt
    }

    public func hashThreadID(_ threadID: String) -> String {
        hash(threadID)
    }

    public func sanitize(
        _ message: JSONRPCMessage,
        receivedAt: Date = Date()
    ) -> CodexReadEvent? {
        let method: String
        let params: JSONValue?
        let isRequest: Bool

        switch message {
        case let .notification(notificationMethod, notificationParams):
            method = notificationMethod
            params = notificationParams
            isRequest = false
        case let .request(_, requestMethod, requestParams):
            method = requestMethod
            params = requestParams
            isRequest = true
        case .response, .error:
            return nil
        }

        let object = params?.objectValue ?? [:]
        let timestamp = parseDate(object["timestamp"]) ?? receivedAt
        let threadID = directOrNestedThreadID(in: object)
        let threadHash = threadID.map(hash)
        let status = directOrNestedStatus(in: object)

        switch method {
        case "thread/started":
            return event(.threadStarted, threadHash, status, timestamp)
        case "thread/status/changed":
            return event(.threadStatusChanged, threadHash, status, timestamp)
        case "turn/started":
            return event(.turnStarted, threadHash, status, timestamp)
        case "turn/completed":
            return event(.turnCompleted, threadHash, status, timestamp)
        case "item/commandExecution/requestApproval" where isRequest,
             "item/tool/requestUserInput" where isRequest:
            return event(.attentionRequired, threadHash, status, timestamp)
        case "error":
            return event(.error, threadHash, status, timestamp)
        case "account/rateLimits/updated":
            return CodexReadEvent(
                category: .rateLimitsUpdated,
                threadIDHash: nil,
                status: nil,
                timestamp: timestamp,
                rateLimits: rateLimits(from: object)
            )
        default:
            return nil
        }
    }

    private func event(
        _ category: CodexEventCategory,
        _ threadIDHash: String?,
        _ status: SanitizedThreadStatus?,
        _ timestamp: Date
    ) -> CodexReadEvent {
        CodexReadEvent(
            category: category,
            threadIDHash: threadIDHash,
            status: status,
            timestamp: timestamp
        )
    }

    private func hash(_ threadID: String) -> String {
        var source = salt
        source.append(0)
        source.append(contentsOf: threadID.utf8)
        return SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
    }

    private func directOrNestedThreadID(in object: [String: JSONValue]) -> String? {
        object["threadId"]?.stringValue
            ?? object["thread"]?.objectValue?["id"]?.stringValue
    }

    private func directOrNestedStatus(
        in object: [String: JSONValue]
    ) -> SanitizedThreadStatus? {
        let statusValue = object["status"]
            ?? object["thread"]?.objectValue?["status"]
        let rawStatus = statusValue?.stringValue
            ?? statusValue?.objectValue?["type"]?.stringValue
        return rawStatus.flatMap(SanitizedThreadStatus.init(rawValue:))
    }

    private func rateLimits(from object: [String: JSONValue]) -> CodexRateLimitUpdate {
        let limits = object["rateLimits"]?.objectValue ?? object
        let primary = limits["primary"]?.objectValue
        let secondary = limits["secondary"]?.objectValue
        return CodexRateLimitUpdate(
            primaryUsedPercent: primary?["usedPercent"]?.numberValue,
            primaryResetAt: parseDate(primary?["resetsAt"] ?? primary?["resetAt"]),
            secondaryUsedPercent: secondary?["usedPercent"]?.numberValue,
            secondaryResetAt: parseDate(secondary?["resetsAt"] ?? secondary?["resetAt"])
        )
    }

    private func parseDate(_ value: JSONValue?) -> Date? {
        switch value {
        case let .string(timestamp):
            return ISO8601DateFormatter().date(from: timestamp)
        case let .number(timestamp):
            return Date(timeIntervalSince1970: timestamp)
        default:
            return nil
        }
    }
}

public enum EventHashSaltStoreError: Error, Equatable {
    case invalidStoredSalt
    case randomGenerationFailed
}

public struct EventHashSaltStore {
    private let root: URL
    private let saltURL: URL
    private let fileManager: FileManager

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        saltURL = root.appending(path: "EventHashSalt")
        self.fileManager = fileManager
    }

    public func loadOrCreate() throws -> Data {
        try fileManager.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)

        if fileManager.fileExists(atPath: saltURL.path) {
            let stored = try Data(contentsOf: saltURL)
            guard stored.count == 32 else { throw EventHashSaltStoreError.invalidStoredSalt }
            return stored
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw EventHashSaltStoreError.randomGenerationFailed
        }
        let salt = Data(bytes)
        try salt.write(to: saltURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: saltURL.path
        )
        return salt
    }
}

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case let .number(value) = self else { return nil }
        return value
    }
}

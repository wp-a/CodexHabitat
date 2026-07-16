import Foundation

public enum CodexEventCategory: String, Codable, Equatable, Sendable {
    case threadStarted
    case threadStatusChanged
    case turnStarted
    case turnCompleted
    case attentionRequired
    case error
    case rateLimitsUpdated
}

public enum SanitizedThreadStatus: String, Codable, Equatable, Sendable {
    case active
    case idle
    case systemError
    case notLoaded
}

public struct CodexRateLimitUpdate: Codable, Equatable, Sendable {
    public let primaryUsedPercent: Double?
    public let primaryResetAt: Date?
    public let secondaryUsedPercent: Double?
    public let secondaryResetAt: Date?

    public init(
        primaryUsedPercent: Double?,
        primaryResetAt: Date?,
        secondaryUsedPercent: Double?,
        secondaryResetAt: Date?
    ) {
        self.primaryUsedPercent = primaryUsedPercent
        self.primaryResetAt = primaryResetAt
        self.secondaryUsedPercent = secondaryUsedPercent
        self.secondaryResetAt = secondaryResetAt
    }
}

public struct CodexReadEvent: Codable, Equatable, Sendable {
    public let category: CodexEventCategory
    public let threadIDHash: String?
    public let status: SanitizedThreadStatus?
    public let timestamp: Date
    public let rateLimits: CodexRateLimitUpdate?

    public init(
        category: CodexEventCategory,
        threadIDHash: String?,
        status: SanitizedThreadStatus?,
        timestamp: Date,
        rateLimits: CodexRateLimitUpdate? = nil
    ) {
        self.category = category
        self.threadIDHash = threadIDHash
        self.status = status
        self.timestamp = timestamp
        self.rateLimits = rateLimits
    }
}

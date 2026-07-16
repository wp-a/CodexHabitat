import Foundation

public enum ConnectionHealth: String, Codable, Equatable, Sendable {
    case online
    case reconnecting
    case offline
}

public struct RateLimitSummary: Codable, Equatable, Sendable {
    public let usedPercent: Double?
    public let resetAt: Date?

    public init(usedPercent: Double?, resetAt: Date?) {
        self.usedPercent = usedPercent
        self.resetAt = resetAt
    }
}

public enum TimerPhase: String, Codable, Equatable, Sendable {
    case idle
    case focus
    case rest
    case paused
}

public struct TimerSummary: Codable, Equatable, Sendable {
    public let phase: TimerPhase
    public let remainingSeconds: Int

    public init(phase: TimerPhase, remainingSeconds: Int) {
        self.phase = phase
        self.remainingSeconds = remainingSeconds
    }
}

public struct HabitatSnapshot: Codable, Equatable, Sendable {
    public let activity: AgentActivity
    public let threadIDHash: String?
    public let eventTimestamp: Date?
    public let connectionHealth: ConnectionHealth
    public let primaryRateLimit: RateLimitSummary?
    public let secondaryRateLimit: RateLimitSummary?
    public let timer: TimerSummary?

    public init(
        activity: AgentActivity = .offline,
        threadIDHash: String? = nil,
        eventTimestamp: Date? = nil,
        connectionHealth: ConnectionHealth = .offline,
        primaryRateLimit: RateLimitSummary? = nil,
        secondaryRateLimit: RateLimitSummary? = nil,
        timer: TimerSummary? = nil
    ) {
        self.activity = activity
        self.threadIDHash = threadIDHash
        self.eventTimestamp = eventTimestamp
        self.connectionHealth = connectionHealth
        self.primaryRateLimit = primaryRateLimit
        self.secondaryRateLimit = secondaryRateLimit
        self.timer = timer
    }
}

import Foundation

public struct CountdownConfiguration: Equatable, Sendable {
    public var durationSeconds: Int

    public init(durationSeconds: Int = 300) {
        self.durationSeconds = durationSeconds
    }

    func validate() throws {
        guard (1...86_400).contains(durationSeconds) else {
            throw WidgetConfigurationError.numericOutOfRange
        }
    }
}

public enum CountdownWidget {
    public static func metric(remainingSeconds: Int?) -> MetricValue {
        guard let remainingSeconds else { return .unavailable }
        return .durationSeconds(max(0, remainingSeconds))
    }
}

public struct CountdownSnapshot: Equatable, Sendable {
    public let remainingSeconds: Int
    public let isRunning: Bool
    public let isComplete: Bool

    public init(remainingSeconds: Int, isRunning: Bool, isComplete: Bool) {
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.isComplete = isComplete
    }
}

public struct CountdownTimer {
    private let configuration: CountdownConfiguration
    private let clock: any TimerClock
    private var remainingSeconds: Int
    private var isRunning = false
    private var updatedAt: Date

    public init(
        configuration: CountdownConfiguration = CountdownConfiguration(),
        clock: any TimerClock = SystemTimerClock()
    ) throws {
        try configuration.validate()
        self.configuration = configuration
        self.clock = clock
        remainingSeconds = configuration.durationSeconds
        updatedAt = clock.now()
    }

    public mutating func start() {
        synchronize()
        if remainingSeconds == 0 {
            remainingSeconds = configuration.durationSeconds
        }
        isRunning = true
        updatedAt = clock.now()
    }

    public mutating func pause() {
        synchronize()
        isRunning = false
        updatedAt = clock.now()
    }

    public mutating func reset() {
        remainingSeconds = configuration.durationSeconds
        isRunning = false
        updatedAt = clock.now()
    }

    public mutating func snapshot() -> CountdownSnapshot {
        synchronize()
        return CountdownSnapshot(
            remainingSeconds: remainingSeconds,
            isRunning: isRunning,
            isComplete: remainingSeconds == 0
        )
    }

    private mutating func synchronize() {
        guard isRunning else { return }
        let now = clock.now()
        let elapsed = max(0, Int(now.timeIntervalSince(updatedAt).rounded(.down)))
        guard elapsed > 0 else { return }
        remainingSeconds = max(0, remainingSeconds - elapsed)
        isRunning = remainingSeconds > 0
        updatedAt = now
    }
}

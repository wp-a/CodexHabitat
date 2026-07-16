import Foundation
import HabitatCore

public struct PomodoroConfiguration: Equatable, Sendable {
    public var focusSeconds: Int
    public var restSeconds: Int

    public init(focusSeconds: Int = 25 * 60, restSeconds: Int = 5 * 60) {
        self.focusSeconds = focusSeconds
        self.restSeconds = restSeconds
    }

    func validate() throws {
        guard (1...86_400).contains(focusSeconds),
              (1...86_400).contains(restSeconds)
        else {
            throw WidgetConfigurationError.numericOutOfRange
        }
    }
}

public struct PomodoroSnapshot: Equatable, Sendable {
    public let phase: TimerPhase
    public let remainingSeconds: Int
    public let isRunning: Bool

    public init(phase: TimerPhase, remainingSeconds: Int, isRunning: Bool) {
        self.phase = phase
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
    }
}

public struct PomodoroPersistedState: Codable, Equatable, Sendable {
    public var phase: TimerPhase
    public var remainingSeconds: Int
    public var isRunning: Bool
    public var updatedAt: Date

    public init(
        phase: TimerPhase,
        remainingSeconds: Int,
        isRunning: Bool,
        updatedAt: Date
    ) {
        self.phase = phase
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.updatedAt = updatedAt
    }
}

public protocol TimerClock: Sendable {
    func now() -> Date
}

public struct SystemTimerClock: TimerClock {
    public init() {}
    public func now() -> Date { Date() }
}

public struct PomodoroTimer {
    private let configuration: PomodoroConfiguration
    private let clock: any TimerClock
    private var state: PomodoroPersistedState

    public init(
        configuration: PomodoroConfiguration = PomodoroConfiguration(),
        clock: any TimerClock = SystemTimerClock(),
        restoredState: PomodoroPersistedState? = nil
    ) throws {
        try configuration.validate()
        self.configuration = configuration
        self.clock = clock
        if let restoredState {
            guard Self.isValid(restoredState, configuration: configuration) else {
                throw WidgetConfigurationError.invalidPersistedState
            }
            state = restoredState
        } else {
            state = PomodoroPersistedState(
                phase: .focus,
                remainingSeconds: configuration.focusSeconds,
                isRunning: false,
                updatedAt: clock.now()
            )
        }
        synchronize()
    }

    public mutating func start() {
        synchronize()
        state.isRunning = true
        state.updatedAt = clock.now()
    }

    public mutating func pause() {
        synchronize()
        state.isRunning = false
        state.updatedAt = clock.now()
    }

    public mutating func reset() {
        state = PomodoroPersistedState(
            phase: .focus,
            remainingSeconds: configuration.focusSeconds,
            isRunning: false,
            updatedAt: clock.now()
        )
    }

    public mutating func snapshot() -> PomodoroSnapshot {
        synchronize()
        return PomodoroSnapshot(
            phase: state.phase,
            remainingSeconds: state.remainingSeconds,
            isRunning: state.isRunning
        )
    }

    public mutating func persistedState() -> PomodoroPersistedState {
        synchronize()
        return state
    }

    private mutating func synchronize() {
        guard state.isRunning else { return }
        let now = clock.now()
        let elapsed = max(0, Int(now.timeIntervalSince(state.updatedAt).rounded(.down)))
        guard elapsed > 0 else { return }

        var remainingElapsed = elapsed
        while remainingElapsed >= state.remainingSeconds {
            remainingElapsed -= state.remainingSeconds
            state.phase = state.phase == .focus ? .rest : .focus
            state.remainingSeconds = duration(for: state.phase)
        }
        state.remainingSeconds -= remainingElapsed
        state.updatedAt = state.updatedAt.addingTimeInterval(TimeInterval(elapsed))
    }

    private func duration(for phase: TimerPhase) -> Int {
        phase == .rest ? configuration.restSeconds : configuration.focusSeconds
    }

    private static func isValid(
        _ state: PomodoroPersistedState,
        configuration: PomodoroConfiguration
    ) -> Bool {
        let maximum: Int
        switch state.phase {
        case .focus:
            maximum = configuration.focusSeconds
        case .rest:
            maximum = configuration.restSeconds
        case .idle, .paused:
            return false
        }
        return (1...maximum).contains(state.remainingSeconds)
    }
}

import Foundation
import Testing
@testable import WidgetRuntime

@Test
func pomodoroStartPauseResetAndPhaseChangeAreDeterministic() throws {
    let clock = TestTimerClock()
    var timer = try PomodoroTimer(
        configuration: PomodoroConfiguration(focusSeconds: 25, restSeconds: 5),
        clock: clock
    )

    #expect(timer.snapshot() == PomodoroSnapshot(phase: .focus, remainingSeconds: 25, isRunning: false))
    timer.start()
    clock.advance(seconds: 7)
    #expect(timer.snapshot() == PomodoroSnapshot(phase: .focus, remainingSeconds: 18, isRunning: true))

    timer.pause()
    clock.advance(seconds: 20)
    #expect(timer.snapshot() == PomodoroSnapshot(phase: .focus, remainingSeconds: 18, isRunning: false))

    timer.start()
    clock.advance(seconds: 18)
    #expect(timer.snapshot() == PomodoroSnapshot(phase: .rest, remainingSeconds: 5, isRunning: true))

    timer.reset()
    #expect(timer.snapshot() == PomodoroSnapshot(phase: .focus, remainingSeconds: 25, isRunning: false))
}

@Test
func runningPomodoroRestoresElapsedTimeAfterRestart() throws {
    let clock = TestTimerClock()
    var timer = try PomodoroTimer(
        configuration: PomodoroConfiguration(focusSeconds: 25, restSeconds: 5),
        clock: clock
    )
    timer.start()
    clock.advance(seconds: 8)
    let persisted = timer.persistedState()
    clock.advance(seconds: 5)

    var restored = try PomodoroTimer(
        configuration: PomodoroConfiguration(focusSeconds: 25, restSeconds: 5),
        clock: clock,
        restoredState: persisted
    )

    #expect(restored.snapshot() == PomodoroSnapshot(phase: .focus, remainingSeconds: 12, isRunning: true))
}

@Test
func timerConfigurationRejectsUnsafeNumericBounds() {
    #expect(throws: WidgetConfigurationError.numericOutOfRange) {
        _ = try PomodoroTimer(
            configuration: PomodoroConfiguration(focusSeconds: 0, restSeconds: 5),
            clock: TestTimerClock()
        )
    }
    #expect(throws: WidgetConfigurationError.numericOutOfRange) {
        _ = try PomodoroTimer(
            configuration: PomodoroConfiguration(focusSeconds: 25, restSeconds: 100_000),
            clock: TestTimerClock()
        )
    }
}

private final class TestTimerClock: TimerClock, @unchecked Sendable {
    private var date = Date(timeIntervalSince1970: 1_700_000_000)

    func now() -> Date { date }

    func advance(seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}

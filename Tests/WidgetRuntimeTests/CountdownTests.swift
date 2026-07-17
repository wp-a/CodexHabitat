import Foundation
import Testing
@testable import WidgetRuntime

@Test
func countdownStartPauseCompletionAndResetAreDeterministic() throws {
    let clock = CountdownTestClock()
    var timer = try CountdownTimer(
        configuration: CountdownConfiguration(durationSeconds: 10),
        clock: clock
    )

    #expect(timer.snapshot() == CountdownSnapshot(
        remainingSeconds: 10,
        isRunning: false,
        isComplete: false
    ))
    timer.start()
    clock.advance(seconds: 4)
    #expect(timer.snapshot().remainingSeconds == 6)
    timer.pause()
    clock.advance(seconds: 8)
    #expect(timer.snapshot().remainingSeconds == 6)

    timer.start()
    clock.advance(seconds: 6)
    #expect(timer.snapshot() == CountdownSnapshot(
        remainingSeconds: 0,
        isRunning: false,
        isComplete: true
    ))

    timer.reset()
    #expect(timer.snapshot().remainingSeconds == 10)
    #expect(!timer.snapshot().isRunning)
}

private final class CountdownTestClock: TimerClock, @unchecked Sendable {
    private var date = Date(timeIntervalSince1970: 1_700_000_000)

    func now() -> Date { date }

    func advance(seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}

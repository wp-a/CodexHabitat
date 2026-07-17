import Foundation
import HabitatCore
import PetRuntime
import Testing
import WidgetRuntime
@testable import CodexHabitatApp

@Test @MainActor
func petAnimationDriverAdvancesWithoutMutatingTheOverlayModel() {
    let clock = OverlayTestClock()
    let model = HabitatOverlayModel(clock: clock, initialSnapshot: HabitatSnapshot(
        activity: .resting,
        connectionHealth: .online
    ))
    let driver = PetAnimationDriver(
        clock: clock,
        initialActivity: model.snapshot.activity,
        availableRows: model.availableRows,
        reduceMotion: model.reduceMotion
    )
    let originalSize = model.overlaySize

    model.apply(HabitatSnapshot(activity: .working, connectionHealth: .online))
    driver.update(activity: model.snapshot.activity)
    #expect(driver.currentFrame().animation == .running)
    #expect(driver.currentFrame().row == 7)
    #expect(driver.currentFrame().column == 0)
    #expect(driver.refreshInterval == 0.125)

    clock.set(121)
    #expect(driver.currentFrame().column == 1)
    #expect(model.overlaySize == originalSize)
}

@Test @MainActor
func inactiveAndReducedMotionPetDriversInstallNoRefreshTimer() {
    let clock = OverlayTestClock()
    let inactive = PetAnimationDriver(
        clock: clock,
        initialActivity: .offline,
        availableRows: Set(0..<9),
        reduceMotion: false
    )
    let reduced = PetAnimationDriver(
        clock: clock,
        initialActivity: .working,
        availableRows: Set(0..<9),
        reduceMotion: true
    )

    #expect(inactive.refreshInterval == nil)
    #expect(reduced.refreshInterval == nil)
    #expect(inactive.currentFrame() == PetFrame(animation: .idle, row: 0, column: 0))
    #expect(reduced.currentFrame() == PetFrame(animation: .idle, row: 0, column: 0))
}

@Test @MainActor
func countdownControlsRunPauseAndReset() {
    let clock = OverlayTimerClock()
    let model = WidgetRailModel(
        countdownConfiguration: CountdownConfiguration(durationSeconds: 10),
        timerClock: clock
    )

    model.toggleCountdown()
    clock.advance(seconds: 4)
    model.refreshTimersForTesting()
    #expect(model.countdownSnapshot.remainingSeconds == 6)
    #expect(model.countdownSnapshot.isRunning)

    model.toggleCountdown()
    model.resetCountdown()
    #expect(model.countdownSnapshot.remainingSeconds == 10)
    #expect(!model.countdownSnapshot.isRunning)
}

private final class OverlayTimerClock: TimerClock, @unchecked Sendable {
    private var date = Date(timeIntervalSince1970: 1_700_000_000)

    func now() -> Date { date }
    func advance(seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }
}

private final class OverlayTestClock: AnimationClock, @unchecked Sendable {
    private var milliseconds: UInt64 = 0

    func nowMilliseconds() -> UInt64 { milliseconds }
    func set(_ value: UInt64) { milliseconds = value }
}

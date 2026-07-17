import Foundation
import HabitatCore
import PetRuntime
import Testing
import WidgetRuntime
@testable import CodexHabitatApp

@Test @MainActor
func snapshotActivityUpdatesPetFrameWithoutChangingOverlaySize() {
    let clock = OverlayTestClock()
    let model = HabitatOverlayModel(clock: clock, initialSnapshot: HabitatSnapshot(
        activity: .resting,
        connectionHealth: .online
    ))
    let originalSize = model.overlaySize

    model.apply(HabitatSnapshot(activity: .working, connectionHealth: .online))
    #expect(model.currentFrame().animation == .running)
    #expect(model.currentFrame().row == 7)
    #expect(model.currentFrame().column == 0)

    clock.set(121)
    #expect(model.currentFrame().column == 1)
    #expect(model.overlaySize == originalSize)
}

@Test @MainActor
func invalidPetFrameKeepsAStableFallbackModel() {
    let model = HabitatOverlayModel(
        clock: OverlayTestClock(),
        initialSnapshot: HabitatSnapshot(activity: .offline, connectionHealth: .offline)
    )

    #expect(model.currentFrame() == PetFrame(animation: .idle, row: 0, column: 0))
    #expect(model.overlaySize == CGSize(width: 160, height: 180))
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

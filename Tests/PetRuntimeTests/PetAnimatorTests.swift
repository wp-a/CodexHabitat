import Foundation
import HabitatCore
import Testing
@testable import PetRuntime

@Test
func officialAnimationRowsAndDurationsMatchThePetContract() {
    let expected: [(PetAnimation, Int, [UInt64])] = [
        (.idle, 0, [280, 110, 110, 140, 140, 320]),
        (.runningRight, 1, [120, 120, 120, 120, 120, 120, 120, 220]),
        (.runningLeft, 2, [120, 120, 120, 120, 120, 120, 120, 220]),
        (.waving, 3, [140, 140, 140, 280]),
        (.jumping, 4, [140, 140, 140, 140, 280]),
        (.failed, 5, [140, 140, 140, 140, 140, 140, 140, 240]),
        (.waiting, 6, [150, 150, 150, 150, 150, 260]),
        (.running, 7, [120, 120, 120, 120, 120, 220]),
        (.review, 8, [150, 150, 150, 150, 150, 280]),
    ]

    #expect(PetAnimation.allCases.count == expected.count)
    for (animation, row, durations) in expected {
        #expect(animation.rowIndex == row)
        #expect(animation.frameDurationsMilliseconds == durations)
        #expect(animation.frameCount == durations.count)
    }
}

@Test
func loopingAnimationHonorsFinalFrameDurationAndWraps() {
    let clock = TestAnimationClock()
    var animator = PetAnimator(clock: clock)
    _ = animator.transition(to: .runningRight)

    clock.set(839)
    #expect(animator.currentFrame().column == 6)
    clock.set(840)
    #expect(animator.currentFrame().column == 7)
    clock.set(1_059)
    #expect(animator.currentFrame().column == 7)
    clock.set(1_060)
    #expect(animator.currentFrame().column == 0)
}

@Test
func activityTransitionsResetAnimationTiming() {
    let clock = TestAnimationClock()
    var animator = PetAnimator(clock: clock, initialActivity: .working)
    clock.set(121)
    #expect(animator.currentFrame().column == 1)

    let attentionFrame = animator.update(activity: .attention)

    #expect(attentionFrame.animation == .waiting)
    #expect(attentionFrame.row == 6)
    #expect(attentionFrame.column == 0)
}

@Test
func unavailableRowsFallBackToIdle() {
    let clock = TestAnimationClock()
    var animator = PetAnimator(
        clock: clock,
        initialActivity: .attention,
        availableRows: [0, 7]
    )

    let frame = animator.currentFrame()

    #expect(frame.animation == .idle)
    #expect(frame.row == 0)
    #expect(frame.column == 0)
}

@Test
func successAnimationPlaysOnceThenFallsBackToIdle() {
    let clock = TestAnimationClock()
    var animator = PetAnimator(clock: clock, initialActivity: .succeeded)
    let reviewDuration = PetAnimation.review.totalDurationMilliseconds

    clock.set(reviewDuration - 1)
    #expect(animator.currentFrame().animation == .review)
    #expect(animator.currentFrame().column == 5)

    clock.set(reviewDuration)
    #expect(animator.currentFrame() == PetFrame(animation: .idle, row: 0, column: 0))
    clock.set(reviewDuration + 1_000)
    #expect(animator.currentFrame().animation == .idle)
}

@Test
func reduceMotionAlwaysUsesTheStableIdleFrame() {
    let clock = TestAnimationClock(milliseconds: 900)
    var animator = PetAnimator(
        clock: clock,
        initialActivity: .failed,
        reduceMotion: true
    )

    #expect(animator.currentFrame() == PetFrame(animation: .idle, row: 0, column: 0))
    #expect(animator.update(activity: .working) == PetFrame(animation: .idle, row: 0, column: 0))
}

@Test
func renderModeResolvesAutoFromTheAssetHint() {
    #expect(PetRenderMode.auto.resolved(pixelArtHint: true) == .pixelated)
    #expect(PetRenderMode.auto.resolved(pixelArtHint: false) == .smooth)
    #expect(PetRenderMode.pixelated.resolved(pixelArtHint: false) == .pixelated)
    #expect(PetRenderMode.smooth.resolved(pixelArtHint: true) == .smooth)
}

private final class TestAnimationClock: AnimationClock, @unchecked Sendable {
    private let lock = NSLock()
    private var milliseconds: UInt64

    init(milliseconds: UInt64 = 0) {
        self.milliseconds = milliseconds
    }

    func nowMilliseconds() -> UInt64 {
        lock.withLock { milliseconds }
    }

    func set(_ milliseconds: UInt64) {
        lock.withLock { self.milliseconds = milliseconds }
    }
}

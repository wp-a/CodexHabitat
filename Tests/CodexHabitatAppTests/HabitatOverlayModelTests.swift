import Foundation
import HabitatCore
import PetRuntime
import Testing
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

private final class OverlayTestClock: AnimationClock, @unchecked Sendable {
    private var milliseconds: UInt64 = 0

    func nowMilliseconds() -> UInt64 { milliseconds }
    func set(_ value: UInt64) { milliseconds = value }
}

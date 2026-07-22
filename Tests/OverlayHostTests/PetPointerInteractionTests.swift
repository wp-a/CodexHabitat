import CoreGraphics
import Testing
@testable import OverlayHost

@Test
func primaryClickPublishesPressAndExactlyOneToggle() {
    var interaction = PetPointerInteraction(dragThreshold: 6)

    let down = interaction.pointerDown(
        at: CGPoint(x: 126, y: 92),
        windowOrigin: CGPoint(x: 100, y: 60)
    )
    let up = interaction.pointerUp(at: CGPoint(x: 129, y: 96))
    let repeatedUp = interaction.pointerUp(at: CGPoint(x: 129, y: 96))

    #expect(down.pressChanged == true)
    #expect(down.command == nil)
    #expect(up.pressChanged == false)
    #expect(up.command == .toggle)
    #expect(repeatedUp == .none)
}

@Test
func dragBeginsAtSixPointsAndPreservesTheInitialGrabOffset() {
    var interaction = PetPointerInteraction(dragThreshold: 6)
    _ = interaction.pointerDown(
        at: CGPoint(x: 126, y: 92),
        windowOrigin: CGPoint(x: 100, y: 60)
    )

    let belowThreshold = interaction.pointerMoved(to: CGPoint(x: 131, y: 92))
    let atThreshold = interaction.pointerMoved(to: CGPoint(x: 132, y: 92))
    let continued = interaction.pointerMoved(to: CGPoint(x: 142, y: 102))
    let up = interaction.pointerUp(at: CGPoint(x: 142, y: 102))

    #expect(belowThreshold == .none)
    #expect(atThreshold.command == .move(to: CGPoint(x: 106, y: 60)))
    #expect(continued.command == .move(to: CGPoint(x: 116, y: 70)))
    #expect(up.pressChanged == false)
    #expect(up.command == .finishMove(at: CGPoint(x: 116, y: 70)))
}

@Test
func cancelledPointerSequenceReleasesPressWithoutDeliveringACommand() {
    var interaction = PetPointerInteraction(dragThreshold: 6)
    _ = interaction.pointerDown(
        at: CGPoint(x: 25, y: 25),
        windowOrigin: CGPoint(x: 10, y: 10)
    )
    _ = interaction.pointerMoved(to: CGPoint(x: 40, y: 40))

    let cancelled = interaction.cancel()
    let lateUp = interaction.pointerUp(at: CGPoint(x: 40, y: 40))

    #expect(cancelled.pressChanged == false)
    #expect(cancelled.command == nil)
    #expect(lateUp == .none)
}

@Test
func aLockedPointerSequenceSuppressesAReleaseAfterLargeMovement() {
    var interaction = PetPointerInteraction(dragThreshold: 6)
    _ = interaction.pointerDown(
        at: CGPoint(x: 40, y: 40),
        windowOrigin: CGPoint(x: 10, y: 10),
        canDrag: false
    )

    #expect(interaction.pointerMoved(to: CGPoint(x: 80, y: 80)) == .none)
    let up = interaction.pointerUp(at: CGPoint(x: 80, y: 80))

    #expect(up.pressChanged == false)
    #expect(up.command == nil)
}

@Test @MainActor
func appKitRegionPublishesImmediatePressAndDeliversOneClick() {
    let region = OverlayDragRegionView()
    region.isInteractionEnabled = true
    region.isDragEnabled = true
    var pressChanges: [Bool] = []
    var clickCount = 0
    region.onPressChange = { pressChanges.append($0) }
    region.onClick = { clickCount += 1 }

    region.handlePointerDown(at: CGPoint(x: 20, y: 30), windowOrigin: .zero)
    #expect(pressChanges == [true])
    region.handlePointerUp(at: CGPoint(x: 22, y: 32))
    region.handlePointerUp(at: CGPoint(x: 22, y: 32))

    #expect(pressChanges == [true, false])
    #expect(clickCount == 1)
}

@Test @MainActor
func disablingAnAppKitRegionCancelsItsActivePointerWithoutACommand() {
    let region = OverlayDragRegionView()
    region.isInteractionEnabled = true
    var pressChanges: [Bool] = []
    var clickCount = 0
    region.onPressChange = { pressChanges.append($0) }
    region.onClick = { clickCount += 1 }

    region.handlePointerDown(at: CGPoint(x: 20, y: 30), windowOrigin: .zero)
    region.isInteractionEnabled = false
    region.handlePointerUp(at: CGPoint(x: 20, y: 30))

    #expect(pressChanges == [true, false])
    #expect(clickCount == 0)
}

@Test
func aNewDownCancelsTheOldSequenceWithoutDuplicatingTerminalCommands() {
    var interaction = PetPointerInteraction(dragThreshold: 6)
    _ = interaction.pointerDown(
        at: CGPoint(x: 10, y: 10),
        windowOrigin: .zero
    )

    let replacementDown = interaction.pointerDown(
        at: CGPoint(x: 20, y: 20),
        windowOrigin: CGPoint(x: 5, y: 5)
    )
    let up = interaction.pointerUp(at: CGPoint(x: 20, y: 20))

    #expect(replacementDown.pressChanged == true)
    #expect(replacementDown.command == nil)
    #expect(up.command == .toggle)
}

@Test
func onlyAnUnmodifiedLeftButtonIsOwnedByThePrimaryPointerPath() {
    #expect(PetPointerInteraction.ownsPrimaryButton(buttonNumber: 0, controlPressed: false))
    #expect(!PetPointerInteraction.ownsPrimaryButton(buttonNumber: 1, controlPressed: false))
    #expect(!PetPointerInteraction.ownsPrimaryButton(buttonNumber: 0, controlPressed: true))
}

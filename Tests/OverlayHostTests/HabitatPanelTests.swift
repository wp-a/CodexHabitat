import AppKit
import Testing
@testable import OverlayHost

@Test @MainActor
func habitatPanelNeverActivatesAndJoinsDesktopSpaces() {
    let panel = HabitatPanel(contentRect: CGRect(x: 0, y: 0, width: 160, height: 180))

    #expect(panel.styleMask.contains(.nonactivatingPanel))
    #expect(panel.level == .statusBar)
    #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
    #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    #expect(!panel.canBecomeKey)
    #expect(!panel.canBecomeMain)
    #expect(!panel.isOpaque)
}

@Test @MainActor
func controllerTogglesClickThroughWithoutChangingPanelSize() {
    let controller = OverlayController(panelSize: CGSize(width: 160, height: 180))
    let originalSize = controller.panel.frame.size

    controller.setInteractive(false)
    #expect(controller.panel.ignoresMouseEvents)
    controller.setInteractive(true)
    #expect(!controller.panel.ignoresMouseEvents)
    #expect(controller.panel.frame.size == originalSize)
}

@Test @MainActor
func positionLockDisablesMovementWithoutDisablingOverlayInteraction() {
    let controller = OverlayController(panelSize: CGSize(width: 160, height: 180))

    controller.setInteractive(true)
    controller.setMovementLocked(true)

    #expect(controller.isInteractive)
    #expect(controller.isMovementLocked)
    #expect(!controller.isMovementEnabled)
    #expect(!controller.panel.ignoresMouseEvents)

    controller.setMovementLocked(false)
    #expect(controller.isMovementEnabled)
}

@Test @MainActor
func dragRegionCanCoverTheCompletePetFrame() {
    let controller = OverlayController(panelSize: CGSize(width: 360, height: 180))
    let petFrame = CGRect(x: 200, y: 0, width: 160, height: 180)

    controller.setDragFrame(petFrame)

    #expect(controller.dragRegionFrame == petFrame)
}

@Test @MainActor
func boundedPanelResizePreservesTheRightEdgeAndUpdatesTheContentGeometry() throws {
    let controller = OverlayController(panelSize: CGSize(width: 324, height: 144))
    controller.panel.setFrameOrigin(CGPoint(x: 400, y: 220))
    let rightEdge = controller.panel.frame.maxX
    var persistedPlacements: [SavedOverlayPlacement] = []
    controller.onPlacementChange = { persistedPlacements.append($0) }

    controller.resize(to: CGSize(width: 136, height: 144), preservingRightEdge: true)

    #expect(controller.panel.frame.size == CGSize(width: 136, height: 144))
    #expect(controller.panel.frame.maxX == rightEdge)
    #expect(persistedPlacements.isEmpty)
    #expect(try #require(controller.panel.contentView).bounds.size == CGSize(width: 136, height: 144))
    controller.setDragFrame(CGRect(origin: .zero, size: CGSize(width: 136, height: 144)))
    #expect(controller.dragRegionFrame == CGRect(x: 0, y: 0, width: 136, height: 144))
    controller.setDragFrame(CGRect(x: 500, y: 500, width: 20, height: 20))
    #expect(controller.dragRegionFrame == .zero)

    controller.resize(to: CGSize(width: 1, height: 9_999), preservingRightEdge: true)
    #expect(controller.panel.frame.size == CGSize(width: 64, height: 2_048))
    #expect(controller.panel.frame.maxX == rightEdge)
    controller.resize(to: CGSize(width: 136, height: 144), preservingRightEdge: true)
    #expect(persistedPlacements.isEmpty)
}

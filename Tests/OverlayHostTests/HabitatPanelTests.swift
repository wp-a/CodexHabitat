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

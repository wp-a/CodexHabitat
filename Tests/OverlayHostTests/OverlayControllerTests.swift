import AppKit
import Testing
@testable import OverlayHost

@Test @MainActor
func animationOwnedResizePreservesTheActivePointerSequence() throws {
    let controller = OverlayController(panelSize: CGSize(width: 136, height: 144))
    controller.setInteractive(true)
    var pressChanges: [Bool] = []
    var clickCount = 0
    controller.onPrimaryPressChange = { pressChanges.append($0) }
    controller.onPrimaryClick = { clickCount += 1 }
    let dragRegion = try #require(controller.panel.contentView?.subviews.compactMap {
        $0 as? OverlayDragRegionView
    }.first)

    dragRegion.handlePointerDown(at: CGPoint(x: 120, y: 80), windowOrigin: .zero)
    controller.resize(
        to: CGSize(width: 180, height: 144),
        preservingRightEdge: true,
        pointerPolicy: .preserve
    )
    dragRegion.handlePointerUp(at: CGPoint(x: 122, y: 82))

    #expect(pressChanges == [true, false])
    #expect(clickCount == 1)
}

@Test @MainActor
func externalResizeCancelsTheActivePointerSequence() throws {
    let controller = OverlayController(panelSize: CGSize(width: 136, height: 144))
    controller.setInteractive(true)
    var pressChanges: [Bool] = []
    var clickCount = 0
    controller.onPrimaryPressChange = { pressChanges.append($0) }
    controller.onPrimaryClick = { clickCount += 1 }
    let dragRegion = try #require(controller.panel.contentView?.subviews.compactMap {
        $0 as? OverlayDragRegionView
    }.first)

    dragRegion.handlePointerDown(at: CGPoint(x: 120, y: 80), windowOrigin: .zero)
    controller.resize(to: CGSize(width: 180, height: 144), preservingRightEdge: true)
    dragRegion.handlePointerUp(at: CGPoint(x: 122, y: 82))

    #expect(pressChanges == [true, false])
    #expect(clickCount == 0)
}

@Test @MainActor
func dragStartIsPublishedOnceWhenThePointerCrossesTheThreshold() throws {
    let controller = OverlayController(panelSize: CGSize(width: 136, height: 144))
    controller.setInteractive(true)
    var dragStartCount = 0
    controller.onPrimaryDragStart = { dragStartCount += 1 }
    let dragRegion = try #require(controller.panel.contentView?.subviews.compactMap {
        $0 as? OverlayDragRegionView
    }.first)

    dragRegion.handlePointerDown(at: CGPoint(x: 20, y: 30), windowOrigin: .zero)
    dragRegion.handlePointerMoved(to: CGPoint(x: 25, y: 30))
    dragRegion.handlePointerMoved(to: CGPoint(x: 26, y: 30))
    dragRegion.handlePointerMoved(to: CGPoint(x: 40, y: 30))

    #expect(dragStartCount == 1)
}

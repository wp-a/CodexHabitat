import Foundation
import Testing
@testable import OverlayHost

@Test
func clampingUsesVisibleFrameInsteadOfFullDisplayFrame() {
    let display = DisplayGeometry(
        id: "main",
        frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
        visibleFrame: CGRect(x: 0, y: 40, width: 1_440, height: 820),
        backingScaleFactor: 2
    )
    let panelSize = CGSize(width: 180, height: 200)

    #expect(display.clampedOrigin(CGPoint(x: -30, y: 800), panelSize: panelSize) == CGPoint(x: 0, y: 660))
    #expect(display.clampedOrigin(CGPoint(x: 1_400, y: 0), panelSize: panelSize) == CGPoint(x: 1_260, y: 40))
}

@Test
func relativePlacementRoundTripsWithinVisibleTravelArea() {
    let display = sampleDisplay(id: "secondary", scale: 1)
    let panelSize = CGSize(width: 200, height: 160)
    let relative = RelativeOverlayPosition(x: 0.25, y: 0.75)

    let origin = display.origin(for: relative, panelSize: panelSize)
    let restored = display.relativePosition(for: origin, panelSize: panelSize)

    #expect(restored.x == relative.x)
    #expect(restored.y == relative.y)
}

@Test
func displayRemovalFallsBackWithoutLosingRelativePosition() throws {
    let saved = SavedOverlayPlacement(
        displayID: "removed",
        relativePosition: RelativeOverlayPosition(x: 0.8, y: 0.2)
    )
    let remaining = sampleDisplay(id: "remaining", scale: 2)

    let resolved = try #require(
        DisplayGeometry.resolve(
            saved: saved,
            panelSize: CGSize(width: 180, height: 200),
            displays: [remaining],
            fallbackDisplayID: "remaining"
        )
    )

    #expect(resolved.display.id == "remaining")
    #expect(
        resolved.origin
            == remaining.origin(for: saved.relativePosition, panelSize: CGSize(width: 180, height: 200))
    )
}

@Test
func scaleFactorChangesDoNotMoveLogicalPlacement() {
    let scaleOne = sampleDisplay(id: "display", scale: 1)
    let scaleTwo = sampleDisplay(id: "display", scale: 2)
    let relative = RelativeOverlayPosition(x: 0.4, y: 0.6)
    let size = CGSize(width: 160, height: 180)

    #expect(scaleOne.origin(for: relative, panelSize: size) == scaleTwo.origin(for: relative, panelSize: size))
}

private func sampleDisplay(id: String, scale: CGFloat) -> DisplayGeometry {
    DisplayGeometry(
        id: id,
        frame: CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080),
        visibleFrame: CGRect(x: 1_440, y: 36, width: 1_920, height: 1_000),
        backingScaleFactor: scale
    )
}

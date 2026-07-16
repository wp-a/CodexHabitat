import CoreGraphics
import Testing
@testable import CodexHabitatApp

@Test
func widgetRailExpansionKeepsThePetFrameStable() {
    let collapsed = HabitatOverlayLayout(isWidgetRailExpanded: false)
    let expanded = HabitatOverlayLayout(isWidgetRailExpanded: true)

    #expect(collapsed.containerSize == CGSize(width: 360, height: 180))
    #expect(expanded.containerSize == collapsed.containerSize)
    #expect(expanded.petFrame == collapsed.petFrame)
    #expect(expanded.petFrame == CGRect(x: 200, y: 0, width: 160, height: 180))
    #expect(collapsed.widgetRailFrame == nil)
    #expect(expanded.widgetRailFrame == CGRect(x: 4, y: 4, width: 184, height: 172))
}

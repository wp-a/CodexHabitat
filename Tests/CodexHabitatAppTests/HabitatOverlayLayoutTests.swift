import CoreGraphics
import HabitatCore
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

@Test
func themeRelativePositionsDetermineSafeCompactWidgetOrder() {
    let enabled: [WidgetIdentifier] = [
        .pomodoro, .countdown, .clock, .usage, .status,
    ]

    let ordered = HabitatWidgetLayoutOrder.resolve(
        enabled: enabled,
        themeWidgets: HabitatThemeDescriptor.builtIn[0].widgets
    )

    #expect(ordered == [.status, .usage, .clock, .pomodoro, .countdown])
}

@Test
func usefulCodexMetricsFitTheDefaultCompactRail() {
    let enabled = HabitatSettings.default.widgetOrder

    #expect(enabled == [.status, .tokens, .context, .speed, .usage])
    #expect(enabled.count * 26 + (enabled.count - 1) + 12 <= Int(HabitatOverlayLayout.widgetRailSize.height))
}

@Test @MainActor
func enablingEveryOptionalWidgetUsesTheRailOverflowPolicy() {
    #expect(WidgetRailView.requiresScrolling(for: WidgetIdentifier.allCases))
    #expect(!WidgetRailView.requiresScrolling(for: HabitatSettings.default.widgetOrder))
}

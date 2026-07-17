import CoreGraphics
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test
func widgetRailExpansionKeepsThePetFrameStable() {
    let collapsed = HabitatOverlayLayout(isWidgetRailExpanded: false)
    let expanded = HabitatOverlayLayout(isWidgetRailExpanded: true)

    #expect(collapsed.containerSize == CGSize(width: 136, height: 144))
    #expect(expanded.containerSize == CGSize(width: 324, height: 144))
    #expect(collapsed.petFrame == CGRect(x: 0, y: 0, width: 136, height: 144))
    #expect(expanded.petFrame == CGRect(x: 188, y: 0, width: 136, height: 144))
    #expect(collapsed.petFrame.maxX == collapsed.containerSize.width)
    #expect(expanded.petFrame.maxX == expanded.containerSize.width)
    #expect(collapsed.widgetRailFrame == nil)
    #expect(expanded.widgetRailFrame == CGRect(x: 4, y: 4, width: 176, height: 136))
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

@Test @MainActor
func usefulCodexMetricsFitTheDefaultCompactRail() {
    let enabled = HabitatSettings.default.widgetOrder

    #expect(enabled == [.status, .tokens, .context, .speed, .usage])
    #expect(WidgetRailView.contentHeight(for: enabled) <= HabitatOverlayLayout.widgetRailSize.height)
}

@Test @MainActor
func enablingEveryOptionalWidgetUsesTheRailOverflowPolicy() {
    #expect(WidgetRailView.requiresScrolling(for: WidgetIdentifier.allCases))
    #expect(!WidgetRailView.requiresScrolling(for: HabitatSettings.default.widgetOrder))
    #expect(WidgetRailView.requiresScrolling(for: [
        .status, .tokens, .context, .speed, .pomodoro,
    ]))
}

import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func healthyNativeLayoutPassesAllRequiredChecks() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let snapshot = LayoutHealthSnapshot(
        sidebarVisible: true,
        mainSurfaceVisible: true,
        composerVisible: true,
        composerAcceptsPointerEvents: true,
        threadCanScroll: true,
        popoversWithinViewport: true,
        controlsWithinViewport: true,
        horizontalOverflowPixels: 0
    )

    let report = LayoutHealthCheck(profile: profile).evaluate(snapshot)

    #expect(report.passed)
    #expect(report.failures.isEmpty)
}

@Test
func brokenNativeSurfacesAndOverflowFailClosed() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let snapshot = LayoutHealthSnapshot(
        sidebarVisible: false,
        mainSurfaceVisible: true,
        composerVisible: false,
        composerAcceptsPointerEvents: false,
        threadCanScroll: false,
        popoversWithinViewport: false,
        controlsWithinViewport: false,
        horizontalOverflowPixels: 24
    )

    let report = LayoutHealthCheck(profile: profile).evaluate(snapshot)

    #expect(!report.passed)
    #expect(Set(report.failures) == Set<LayoutHealthFailure>([
        .sidebarMissingOrHidden,
        .composerMissingOrHidden,
        .composerPointerEventsDisabled,
        .threadNotScrollable,
        .popoverOutsideViewport,
        .controlOutsideViewport,
        .horizontalOverflow,
    ]))
}

@Test
func generatedHealthScriptUsesOnlyTheVersionedProfileSelectors() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let script = LayoutHealthCheck(profile: profile).evaluationScript()

    #expect(script.contains(profile.selectors.sidebar))
    #expect(script.contains(profile.selectors.composer))
    #expect(script.contains(profile.selectors.threadScroll))
    #expect(script.contains("threadCanScroll: !!thread &&"))
    #expect(!script.contains("https://"))
    #expect(!script.contains("eval("))
}

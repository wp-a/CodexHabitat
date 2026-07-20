import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func healthyTaskLayoutPassesAllRequiredChecks() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let snapshot = LayoutHealthSnapshot(
        route: .task,
        appShellVisible: true,
        sidebarVisible: true,
        mainSurfaceVisible: true,
        headerVisible: true,
        composerVisible: true,
        composerAcceptsPointerEvents: true,
        composerHitTestable: true,
        threadCanScroll: true,
        requiredSurfaceAnnotationsPresent: true,
        popoversWithinViewport: true,
        controlsWithinViewport: true,
        horizontalOverflowPixels: 0
    )

    let report = LayoutHealthCheck(profile: profile).evaluate(snapshot)

    #expect(report.passed)
    #expect(report.failures.isEmpty)
}

@Test
func healthyHomeLayoutDoesNotRequireTaskComposerOrThreadScroll() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let snapshot = LayoutHealthSnapshot(
        route: .home,
        appShellVisible: true,
        sidebarVisible: true,
        mainSurfaceVisible: true,
        headerVisible: true,
        composerVisible: false,
        composerAcceptsPointerEvents: false,
        composerHitTestable: false,
        threadCanScroll: false,
        requiredSurfaceAnnotationsPresent: true,
        popoversWithinViewport: true,
        controlsWithinViewport: true,
        horizontalOverflowPixels: 0
    )

    let report = LayoutHealthCheck(profile: profile).evaluate(snapshot)

    #expect(report.passed)
    #expect(report.failures.isEmpty)
}

@Test
func taskLayoutStillRequiresComposerAndThreadScroll() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let snapshot = LayoutHealthSnapshot(
        route: .task,
        appShellVisible: true,
        sidebarVisible: true,
        mainSurfaceVisible: true,
        headerVisible: true,
        composerVisible: false,
        composerAcceptsPointerEvents: false,
        composerHitTestable: false,
        threadCanScroll: false,
        requiredSurfaceAnnotationsPresent: true,
        popoversWithinViewport: true,
        controlsWithinViewport: true,
        horizontalOverflowPixels: 0
    )

    let report = LayoutHealthCheck(profile: profile).evaluate(snapshot)

    #expect(!report.passed)
    #expect(Set(report.failures) == Set<LayoutHealthFailure>([
        .composerMissingOrHidden,
        .composerPointerEventsDisabled,
        .composerHitTestingFailed,
        .threadNotScrollable,
    ]))
}

@Test
func brokenNativeSurfacesAndOverflowFailClosed() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let snapshot = LayoutHealthSnapshot(
        route: .task,
        appShellVisible: false,
        sidebarVisible: false,
        mainSurfaceVisible: true,
        headerVisible: false,
        composerVisible: false,
        composerAcceptsPointerEvents: false,
        composerHitTestable: false,
        threadCanScroll: false,
        requiredSurfaceAnnotationsPresent: false,
        popoversWithinViewport: false,
        controlsWithinViewport: false,
        horizontalOverflowPixels: 24
    )

    let report = LayoutHealthCheck(profile: profile).evaluate(snapshot)

    #expect(!report.passed)
    #expect(Set(report.failures) == Set<LayoutHealthFailure>([
        .appShellMissingOrHidden,
        .sidebarMissingOrHidden,
        .headerMissingOrHidden,
        .composerMissingOrHidden,
        .composerPointerEventsDisabled,
        .composerHitTestingFailed,
        .threadNotScrollable,
        .requiredSurfaceAnnotationMissing,
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
    #expect(script.contains(profile.selectors.header))
    #expect(script.contains("const isHome = !!document.querySelector"))
    #expect(script.contains("data-testid=\\\"home-icon\\\""))
    #expect(script.contains("document.elementFromPoint"))
    #expect(script.contains("requiredSurfaceAnnotationsPresent"))
    #expect(script.contains("const appShell = document.body"))
    #expect(script.contains("const expectedSurfaces = new Map()"))
    #expect(script.contains("threadCanScroll: visible(thread) &&"))
    #expect(script.contains("route: isHome ? \"home\" : \"task\""))
    #expect(script.contains("isHome ? [sidebar, main, header] : [sidebar, main, header, composer]"))
    #expect(!script.contains("https://"))
    #expect(!script.contains("eval("))
}

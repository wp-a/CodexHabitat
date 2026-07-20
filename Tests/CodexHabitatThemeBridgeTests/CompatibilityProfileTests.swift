import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func currentBuildProfileOwnsCompleteSafeHostSurfaceMap() throws {
    let store = try CompatibilityProfileStore.bundled()
    let baseline = try #require(store.profile(forVersion: "26.715.31251"))
    let current = try #require(store.profile(forVersion: "26.715.31925"))

    #expect(baseline.id == "codex-26.715")
    #expect(baseline.selectors.appShell == nil)
    #expect(current.id == "codex-26.715.31925")
    #expect(current.selectors.appShell == "#root")
    #expect(current.selectors.homeContent == "main.main-surface [role=\"main\"]")
    #expect(current.selectors.homeSuggestions == "[class~=\"group/home-suggestions\"]")
    #expect(current.selectors.selectedNavigation == "aside.app-shell-left-panel [aria-current]")
    #expect(current.selectors.taskTranscript == ".thread-scroll-container")
    #expect(current.selectors.userMessageSurface == "[data-user-message-bubble]")
    #expect(current.selectors.messageSurface == "[data-content-search-unit-key]")
    #expect(current.selectors.codeSurface == "[data-content-search-unit-key] pre")
    #expect(current.selectors.toolSurfaces == [
        "[data-content-search-unit-key] [data-testid=\"exec-shell-body\"]",
        "[data-content-search-unit-key] [data-testid=\"dynamic-tool-call-group-body\"]",
        "[data-content-search-unit-key] [data-testid=\"pending-mcp-tool-calls-body\"]",
    ])
    #expect(current.selectors.sidebarResizeChrome ==
        "aside.app-shell-left-panel .sidebar-resize-handle-line")
    #expect(current.selectors.topFade == ".app-shell-main-content-top-fade")
    #expect(current.selectors.bottomFade ==
        ".thread-scroll-container [data-thread-scroll-footer=\"true\"] > [class~=\"pointer-events-none\"]")
    #expect(current.selectors.composerContext ==
        "main.main-surface [data-codex-composer-root]")
    #expect(current.selectors.stickyBand == nil)
    #expect(baseline.selectors.userMessageSurface == nil)

    #expect(store.profile(forVersion: "26.715.31924")?.id == "codex-26.715")
    #expect(store.profile(forVersion: "26.715.31926") == nil)
}

@Test
func updatedBuildProfileReusesOnlyTheStaticallyAuditedExactSurfaceMap() throws {
    let store = try CompatibilityProfileStore.bundled()
    let previous = try #require(store.profile(forVersion: "26.715.31925"))
    let updated = try #require(store.profile(forVersion: "26.715.52143"))

    #expect(updated.id == "codex-26.715.52143")
    #expect(updated.minimumVersion == "26.715.52143")
    #expect(updated.maximumVersionExclusive == "26.715.52144")
    #expect(updated.selectors == previous.selectors)
    #expect(store.profile(forVersion: "26.715.52142") == nil)
    #expect(store.profile(forVersion: "26.715.52144") == nil)
}

@Test(arguments: [
    "body *",
    "script",
    "main:has(form)",
    "li:nth-child(2)",
    "[aria-label=\"user text\"]",
    "[title=\"tooltip\"]",
    "[href=\"https://example.com\"]",
    "https://example.com",
    "main, aside",
    "main { color: red; }",
])
func extendedHostSurfacesRejectUnsafeSelectors(_ selector: String) throws {
    #expect(throws: CompatibilityProfileError.unsafeSelector(selector)) {
        try CompatibilityProfileStore(data: try profileDocument(appShell: selector))
    }
}

@Test
func profileRangesMustBeOrderedNonEmptyAndDisjoint() throws {
    #expect(throws: CompatibilityProfileError.invalidVersionRange("empty")) {
        try CompatibilityProfileStore(data: try profileDocument(
            profiles: [profileObject(
                id: "empty",
                minimum: "26.715.1",
                maximum: "26.715.1"
            )]
        ))
    }

    #expect(throws: CompatibilityProfileError.overlappingProfiles("first", "second")) {
        try CompatibilityProfileStore(data: try profileDocument(
            profiles: [
                profileObject(
                    id: "first",
                    minimum: "26.715.0",
                    maximum: "26.715.20"
                ),
                profileObject(
                    id: "second",
                    minimum: "26.715.10",
                    maximum: "26.716.0"
                ),
            ]
        ))
    }
}

private func profileDocument(appShell: String) throws -> Data {
    try profileDocument(profiles: [profileObject(
        id: "sentinel",
        minimum: "26.715.0",
        maximum: "26.716.0",
        appShell: appShell
    )])
}

private func profileDocument(profiles: [[String: Any]]) throws -> Data {
    try JSONSerialization.data(withJSONObject: [
        "schemaVersion": 1,
        "profiles": profiles,
    ], options: [.sortedKeys])
}

private func profileObject(
    id: String,
    minimum: String,
    maximum: String,
    appShell: String = "#root"
) -> [String: Any] {
    [
        "id": id,
        "minimumVersion": minimum,
        "maximumVersionExclusive": maximum,
        "selectors": [
            "sidebar": "aside.app-shell-left-panel",
            "mainSurface": "main.main-surface",
            "composer": ".composer-surface-chrome",
            "threadScroll": ".thread-scroll-container",
            "popover": "[data-radix-popper-content-wrapper]",
            "header": "main.main-surface > header.app-header-tint",
            "homeMarker": "[data-testid=\"home-icon\"]",
            "appShell": appShell,
        ],
    ]
}

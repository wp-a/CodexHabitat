import CoreGraphics
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test
func habitatOverviewBuildsThreeDeterministicSections() throws {
    let state = HabitatOverviewState(
        isHabitatVisible: true,
        selectedPetName: "Mochi",
        positionLocked: true,
        enabledWidgetCount: 4,
        connectionHealth: .online,
        hasSanitizedMetrics: true,
        selectedThemeName: "Workbench",
        themeSupportsCodexBridge: true,
        themeBridgeState: .active,
        canRestoreOfficialAppearance: true
    )

    #expect(state.sections.map(\.kind) == [.habitat, .codex, .appearance])
    #expect(state.sections.allSatisfy { $0.facts.count <= 3 })

    let habitat = try #require(state.sections.first)
    #expect(habitat.title == "Habitat")
    #expect(habitat.primary == "Visible")
    #expect(habitat.facts == ["Mochi", "Position locked", "4 widgets enabled"])
    #expect(habitat.actions == [
        .setHabitatVisibility(false),
        .setPositionLocked(false),
    ])

    let codex = state.sections[1]
    #expect(codex.title == "Codex")
    #expect(codex.primary == "Connected")
    #expect(codex.facts == ["Sanitized metrics available", "Local read only"])
    #expect(codex.actions == [.navigate(.integrations)])

    let appearance = state.sections[2]
    #expect(appearance.title == "Appearance")
    #expect(appearance.primary == "Workbench")
    #expect(appearance.facts == [
        "Codex compatible",
        "Bridge active",
        "Restore available",
    ])
    #expect(appearance.actions == [.navigate(.themes)])
}

@Test
func habitatOverviewUsesUsefulFallbacksWithoutInventingState() {
    let state = HabitatOverviewState(
        isHabitatVisible: false,
        selectedPetName: nil,
        positionLocked: false,
        enabledWidgetCount: 0,
        connectionHealth: nil,
        hasSanitizedMetrics: false,
        selectedThemeName: nil,
        themeSupportsCodexBridge: false,
        themeBridgeState: .unavailable,
        canRestoreOfficialAppearance: false
    )

    #expect(state.sections[0].primary == "Hidden")
    #expect(state.sections[0].facts == [
        "No pet selected",
        "Position unlocked",
        "Widget rail off",
    ])
    #expect(state.sections[0].actions == [
        .setHabitatVisibility(true),
        .setPositionLocked(true),
    ])
    #expect(state.sections[1].primary == "Connection unavailable")
    #expect(state.sections[1].facts == ["Sanitized metrics unavailable", "Local read only"])
    #expect(state.sections[2].primary == "Default appearance")
    #expect(state.sections[2].facts == [
        "Habitat only",
        "Bridge unavailable",
        "Official appearance",
    ])
}

@Test(arguments: [
    (false, true),
    (true, false),
])
func habitatOverviewOffersTheInversePositionLockAction(
    positionLocked: Bool,
    requestedLockState: Bool
) {
    let state = HabitatOverviewState(
        isHabitatVisible: true,
        selectedPetName: "Pet",
        positionLocked: positionLocked,
        enabledWidgetCount: 1,
        connectionHealth: .online,
        hasSanitizedMetrics: true,
        selectedThemeName: "Theme",
        themeSupportsCodexBridge: true,
        themeBridgeState: .ready,
        canRestoreOfficialAppearance: false
    )

    #expect(state.sections[0].actions.contains(.setPositionLocked(requestedLockState)))
}

@Test
func habitatOverviewUsesOnlySanitizedFieldsFromASuppliedSnapshot() {
    let snapshot = HabitatSnapshot(
        threadIDHash: "private-thread-sentinel",
        connectionHealth: .online,
        tokenMetrics: TokenMetricsSummary(
            inputTokens: 100,
            cachedInputTokens: 20,
            outputTokens: 40,
            reasoningOutputTokens: 10,
            totalTokens: 150,
            lastInputTokens: 30,
            lastOutputTokens: 12,
            modelContextWindow: 200_000,
            recentOutputTokens: 8,
            updatedAt: .distantPast
        )
    )
    let state = HabitatOverviewState(
        isHabitatVisible: true,
        selectedPetName: "Pet",
        positionLocked: false,
        enabledWidgetCount: 2,
        snapshot: snapshot,
        selectedThemeName: "Theme",
        themeSupportsCodexBridge: true,
        themeBridgeState: .ready,
        canRestoreOfficialAppearance: false
    )

    #expect(state.sections[1].primary == "Connected")
    #expect(state.sections[1].facts.contains("Sanitized metrics available"))
    let visibleContent = state.sections.flatMap { [$0.primary] + $0.facts }.joined()
    #expect(!visibleContent.contains("private-thread-sentinel"))
}

@Test(arguments: [
    (ConnectionHealth.online, "Connected"),
    (.estimated, "Estimated connection"),
    (.reconnecting, "Reconnecting"),
    (.offline, "Not connected"),
])
func habitatOverviewDescribesHeldConnectionHealth(
    health: ConnectionHealth,
    expected: String
) {
    let state = HabitatOverviewState(
        isHabitatVisible: true,
        selectedPetName: "Pet",
        positionLocked: false,
        enabledWidgetCount: 1,
        connectionHealth: health,
        hasSanitizedMetrics: false,
        selectedThemeName: "Theme",
        themeSupportsCodexBridge: true,
        themeBridgeState: .ready,
        canRestoreOfficialAppearance: false
    )

    #expect(state.sections[1].primary == expected)
}

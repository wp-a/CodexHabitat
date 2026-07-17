import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test @MainActor
func completedSetupShowsAndHidesTheDesktopHabitat() {
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true

    controller.apply(settings: settings, pets: [], isVisible: true)

    #expect(controller.isVisible)
    #expect(controller.panelSize == HabitatOverlayLayout.containerSize)
    #expect(controller.isInteractive)

    settings.clickThrough = true
    controller.apply(settings: settings, pets: [], isVisible: true)
    #expect(controller.isInteractive == false)

    controller.apply(settings: settings, pets: [], isVisible: false)
    #expect(controller.isVisible == false)
}

@Test @MainActor
func incompleteSetupNeverShowsTheDesktopHabitat() {
    let controller = HabitatDesktopController()

    controller.apply(settings: .default, pets: [], isVisible: true)

    #expect(controller.isVisible == false)
}

@Test @MainActor
func liveSnapshotUpdatesDesktopPetAndWidgets() {
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    controller.apply(settings: settings, pets: [], isVisible: true)
    let snapshot = HabitatSnapshot(
        activity: .attention,
        threadIDHash: "local-hash",
        eventTimestamp: Date(timeIntervalSince1970: 250),
        connectionHealth: .online,
        primaryRateLimit: RateLimitSummary(usedPercent: 31, resetAt: nil)
    )

    controller.apply(snapshot: snapshot)

    #expect(controller.currentSnapshot == snapshot)
    #expect(controller.currentPetSnapshot == snapshot)
    #expect(controller.currentWidgetSnapshot == snapshot)
}

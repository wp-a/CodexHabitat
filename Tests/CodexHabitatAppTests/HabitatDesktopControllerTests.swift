import Foundation
import HabitatCore
import PetRuntime
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

@Test @MainActor
func desktopUsesASelectedInstalledThemeDescriptor() {
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedThemeID = "studio.example.theme"
    let theme = HabitatThemeDescriptor(
        id: "studio.example.theme",
        name: "Installed Theme",
        detail: "Fixture",
        symbol: "shippingbox.fill",
        surfaceHex: "#101010",
        textHex: "#F0F0F0",
        accentHex: "#00A0A0",
        attentionHex: "#F0A000",
        errorHex: "#E04040",
        previewURL: nil
    )

    controller.apply(settings: settings, pets: [], isVisible: true, themes: [theme])

    #expect(controller.currentThemeID == theme.id)
}

@Test @MainActor
func desktopConsumesResourcePetRenderingAndScale() throws {
    let testsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let petRoot = testsRoot.appending(path: "PetRuntimeTests/Fixtures", directoryHint: .isDirectory)
    let pet = try #require(
        PetLibrary(root: petRoot).discover().first(where: { $0.manifest?.id == "test-pet" })
    )
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedPetID = "test-pet"

    controller.apply(
        settings: settings,
        pets: [pet],
        petPresentations: [
            "test-pet": HabitatPetPresentation(renderMode: .smooth, scale: 1.5),
        ],
        isVisible: true
    )

    #expect(controller.currentPetRenderMode == .smooth)
    #expect(controller.currentPetScale == 1.5)
}

import Foundation
import HabitatCore
import PetRuntime
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Equatable, Sendable {
    case habitat
    case pet
    case widgets
}

enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case habitat
    case pets
    case widgets
    case themes
    case integrations
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .habitat: "Habitat"
        case .pets: "Pets"
        case .widgets: "Widgets"
        case .themes: "Themes"
        case .integrations: "Integrations"
        case .privacy: "Privacy"
        }
    }

    var systemImage: String {
        switch self {
        case .habitat: "macwindow"
        case .pets: "pawprint.fill"
        case .widgets: "rectangle.3.group.fill"
        case .themes: "paintpalette.fill"
        case .integrations: "point.3.connected.trianglepath.dotted"
        case .privacy: "hand.raised.fill"
        }
    }
}

struct HabitatThemeDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let detail: String
    let symbol: String

    static let builtIn = [
        HabitatThemeDescriptor(
            id: "workbench",
            name: "Workbench",
            detail: "Bright and tool-oriented",
            symbol: "hammer.fill"
        ),
        HabitatThemeDescriptor(
            id: "night-shift",
            name: "Night Shift",
            detail: "Dark with teal and amber signals",
            symbol: "moon.stars.fill"
        ),
        HabitatThemeDescriptor(
            id: "arcade-signal",
            name: "Arcade Signal",
            detail: "Crisp primary accents for pixel pets",
            symbol: "arcade.stick.console.fill"
        ),
        HabitatThemeDescriptor(
            id: "quiet-garden",
            name: "Quiet Garden",
            detail: "Soft green with cherry accents",
            symbol: "leaf.fill"
        ),
    ]
}

@MainActor
final class HabitatAppModel: ObservableObject {
    @Published private(set) var settings = HabitatSettings.default
    @Published private(set) var validPets: [PetLibraryEntry] = []
    @Published private(set) var onboardingStep = OnboardingStep.habitat
    @Published var selectedSettingsSection = SettingsSection.habitat
    @Published private(set) var isLoaded = false
    @Published private(set) var errorMessage: String?
    @Published var isHabitatVisible = true

    let requiresAccount = false

    private let settingsStore: SettingsStore
    private let petRoot: URL
    private var saveTask: Task<Void, Never>?

    var requiresOnboarding: Bool { !settings.onboardingCompleted }

    init(settingsStore: SettingsStore, petRoot: URL) {
        self.settingsStore = settingsStore
        self.petRoot = petRoot
    }

    static func live(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> HabitatAppModel {
        let root: URL
        if let configuredRoot = environment["CODEX_HABITAT_HOME"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !configuredRoot.isEmpty {
            root = URL(fileURLWithPath: configuredRoot, isDirectory: true)
        } else {
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
            root = applicationSupport.appending(path: "Codex Habitat", directoryHint: .isDirectory)
        }
        return HabitatAppModel(
            settingsStore: SettingsStore(root: root),
            petRoot: PetLibrary.petRoot()
        )
    }

    func load() async {
        guard !isLoaded else { return }
        do {
            settings = try await settingsStore.load()
        } catch {
            settings = .default
            errorMessage = "Settings could not be loaded. Defaults are active."
        }

        validPets = ((try? PetLibrary(root: petRoot).discover()) ?? [])
            .filter { $0.status == .valid }
        let validPetIDs = Set(validPets.compactMap(\.manifest?.id))
        var repairedSettings = normalized(settings)
        if repairedSettings.selectedPetID.map(validPetIDs.contains) != true {
            repairedSettings.selectedPetID = validPets.first?.manifest?.id
        }
        let settingsChanged = repairedSettings != settings
        settings = repairedSettings
        isLoaded = true

        if settingsChanged, settings.onboardingCompleted {
            do {
                try await settingsStore.save(settings)
            } catch {
                errorMessage = "The repaired settings could not be saved."
            }
        }
    }

    func advanceOnboarding() async -> Bool {
        switch onboardingStep {
        case .habitat:
            onboardingStep = .pet
            return false
        case .pet:
            onboardingStep = .widgets
            return false
        case .widgets:
            settings.onboardingCompleted = true
            await flushSettings()
            return true
        }
    }

    func moveBackOnboarding() {
        guard let previous = OnboardingStep(rawValue: onboardingStep.rawValue - 1) else { return }
        onboardingStep = previous
    }

    func restartOnboarding() {
        onboardingStep = .habitat
        updateSettings { $0.onboardingCompleted = false }
    }

    func refreshPets() {
        validPets = ((try? PetLibrary(root: petRoot).discover()) ?? [])
            .filter { $0.status == .valid }
        let validIDs = Set(validPets.compactMap(\.manifest?.id))
        if settings.selectedPetID.map(validIDs.contains) != true {
            updateSettings { $0.selectedPetID = validPets.first?.manifest?.id }
        }
    }

    func selectPet(_ id: String?) {
        let validIDs = Set(validPets.compactMap(\.manifest?.id))
        guard id == nil || id.map(validIDs.contains) == true else { return }
        updateSettings { $0.selectedPetID = id }
    }

    func selectTheme(_ id: String) {
        guard HabitatThemeDescriptor.builtIn.contains(where: { $0.id == id }) else { return }
        updateSettings { $0.selectedThemeID = id }
    }

    func setWidget(_ id: WidgetIdentifier, enabled: Bool) {
        updateSettings { settings in
            var enabledWidgets = Set(settings.widgetOrder)
            if enabled {
                enabledWidgets.insert(id)
            } else {
                enabledWidgets.remove(id)
            }
            settings.widgetOrder = WidgetIdentifier.allCases.filter(enabledWidgets.contains)
        }
    }

    func setScale(_ value: Double) {
        updateSettings { $0.scale = min(max(value, 0.75), 1.5) }
    }

    func setClickThrough(_ enabled: Bool) {
        updateSettings { $0.clickThrough = enabled }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        updateSettings { $0.launchAtLogin = enabled }
    }

    func setReduceMotion(_ preference: ReduceMotionPreference) {
        updateSettings { $0.reduceMotion = preference }
    }

    func setThemeBridgeEnabled(_ enabled: Bool) {
        updateSettings { $0.themeBridgeEnabled = enabled }
    }

    func flushSettings() async {
        saveTask?.cancel()
        saveTask = nil
        do {
            try await settingsStore.save(settings)
        } catch {
            errorMessage = "Settings could not be saved."
        }
    }

    private func updateSettings(_ update: (inout HabitatSettings) -> Void) {
        update(&settings)
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = settings
        let store = settingsStore
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(150))
                try Task.checkCancellation()
                try await store.save(snapshot)
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = "Settings could not be saved."
            }
        }
    }

    private func normalized(_ source: HabitatSettings) -> HabitatSettings {
        var result = source
        if !HabitatThemeDescriptor.builtIn.contains(where: { $0.id == result.selectedThemeID }) {
            result.selectedThemeID = HabitatSettings.default.selectedThemeID
        }
        let knownWidgets = Set(WidgetIdentifier.allCases)
        var seen: Set<WidgetIdentifier> = []
        result.widgetOrder = result.widgetOrder.filter {
            knownWidgets.contains($0) && seen.insert($0).inserted
        }
        result.scale = min(max(result.scale, 0.75), 1.5)
        return result
    }
}

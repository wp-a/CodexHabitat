import Foundation
import HabitatCore
import PetRuntime
import ResourceKit
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
    let surfaceHex: String
    let textHex: String
    let accentHex: String
    let attentionHex: String
    let errorHex: String
    let previewURL: URL?

    static let builtIn = [
        bundled(
            id: "workbench",
            name: "Workbench",
            detail: "Bright and tool-oriented",
            symbol: "hammer.fill",
            fallbackColors: ("#F4F7F8", "#172126", "#0F8B8D", "#D97706", "#D64545")
        ),
        bundled(
            id: "night-shift",
            name: "Night Shift",
            detail: "Dark with teal and amber signals",
            symbol: "moon.stars.fill",
            fallbackColors: ("#171A1D", "#F1F5F6", "#2DD4BF", "#F59E0B", "#FB7185")
        ),
        bundled(
            id: "arcade-signal",
            name: "Arcade Signal",
            detail: "Crisp primary accents for pixel pets",
            symbol: "arcade.stick.console.fill",
            fallbackColors: ("#14151A", "#F7F7F2", "#2D8CFF", "#FFD23F", "#FF4D5A")
        ),
        bundled(
            id: "quiet-garden",
            name: "Quiet Garden",
            detail: "Soft green with cherry accents",
            symbol: "leaf.fill",
            fallbackColors: ("#F5F8F4", "#203127", "#3D8B63", "#C86A45", "#C4455D")
        ),
    ]

    private static func bundled(
        id: String,
        name: String,
        detail: String,
        symbol: String,
        fallbackColors: (String, String, String, String, String)
    ) -> HabitatThemeDescriptor {
        let directory = "Resources/Themes/\(id)"
        let manifestURL = PackagedResourceLocator.url(
            forResource: "habitat",
            withExtension: "json",
            subdirectory: directory
        ) ?? Bundle.module.url(
            forResource: "habitat",
            withExtension: "json",
            subdirectory: directory
        )
        let manifest = manifestURL.flatMap { url in
            try? ManifestDecoder(runtimeVersion: "1.0.0").decode(Data(contentsOf: url))
        }
        return HabitatThemeDescriptor(
            id: id,
            name: manifest?.name ?? name,
            detail: detail,
            symbol: symbol,
            surfaceHex: manifest?.colors.surface ?? fallbackColors.0,
            textHex: manifest?.colors.text ?? fallbackColors.1,
            accentHex: manifest?.colors.accent ?? fallbackColors.2,
            attentionHex: manifest?.colors.attention ?? fallbackColors.3,
            errorHex: manifest?.colors.error ?? fallbackColors.4,
            previewURL: PackagedResourceLocator.url(
                forResource: "preview",
                withExtension: "png",
                subdirectory: directory
            ) ?? Bundle.module.url(
                forResource: "preview",
                withExtension: "png",
                subdirectory: directory
            )
        )
    }
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
    private let resourceLibraryRoot: URL?
    private var saveTask: Task<Void, Never>?

    var requiresOnboarding: Bool { !settings.onboardingCompleted }

    init(
        settingsStore: SettingsStore,
        petRoot: URL,
        resourceLibraryRoot: URL? = nil
    ) {
        self.settingsStore = settingsStore
        self.petRoot = petRoot
        self.resourceLibraryRoot = resourceLibraryRoot
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
            petRoot: PetLibrary.petRoot(),
            resourceLibraryRoot: root.appending(path: "Library", directoryHint: .isDirectory)
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

        validPets = discoverValidPets()
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
        validPets = discoverValidPets()
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

    private func discoverValidPets() -> [PetLibraryEntry] {
        let local = ((try? PetLibrary(root: petRoot).discover()) ?? [])
            .filter { $0.status == .valid }
        var result: [PetLibraryEntry] = []
        var identifiers: Set<String> = []
        for entry in local {
            guard let id = entry.manifest?.id, identifiers.insert(id).inserted else { continue }
            result.append(entry)
        }

        guard let resourceLibraryRoot else { return result }
        let packages = InstalledPackageLibrary(
            root: resourceLibraryRoot,
            runtimeVersion: "1.0.0"
        ).currentPackages()
        let validator = PetValidator()
        for package in packages {
            for adapter in package.manifest.pets {
                let directory = package.url.appending(
                    path: adapter.path,
                    directoryHint: .isDirectory
                )
                let entry = validator.validate(directory: directory)
                guard entry.status == .valid,
                      entry.manifest?.id == adapter.id,
                      identifiers.insert(adapter.id).inserted
                else {
                    continue
                }
                result.append(entry)
            }
        }
        return result
    }
}

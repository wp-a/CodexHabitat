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
    let panelHex: String
    let panelAltHex: String
    let textHex: String
    let mutedTextHex: String
    let accentHex: String
    let secondaryHex: String
    let highlightHex: String
    let attentionHex: String
    let errorHex: String
    let previewURL: URL?
    let backgroundURL: URL?
    let category: HabitatThemeCategory
    let styleFamily: HabitatThemeStyleFamily
    let appearance: HabitatThemeAppearance
    let widgets: [HabitatWidget]

    init(
        id: String,
        name: String,
        detail: String,
        symbol: String,
        surfaceHex: String,
        panelHex: String? = nil,
        panelAltHex: String? = nil,
        textHex: String,
        mutedTextHex: String? = nil,
        accentHex: String,
        secondaryHex: String? = nil,
        highlightHex: String? = nil,
        attentionHex: String,
        errorHex: String,
        previewURL: URL?,
        backgroundURL: URL? = nil,
        category: HabitatThemeCategory = .custom,
        styleFamily: HabitatThemeStyleFamily = .gameCinematic,
        appearance: HabitatThemeAppearance? = nil,
        widgets: [HabitatWidget] = []
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.surfaceHex = surfaceHex
        self.panelHex = panelHex ?? surfaceHex
        self.panelAltHex = panelAltHex ?? accentHex
        self.textHex = textHex
        self.mutedTextHex = mutedTextHex ?? textHex
        self.accentHex = accentHex
        self.secondaryHex = secondaryHex ?? attentionHex
        self.highlightHex = highlightHex ?? accentHex
        self.attentionHex = attentionHex
        self.errorHex = errorHex
        self.previewURL = previewURL
        self.backgroundURL = backgroundURL
        self.category = category
        self.styleFamily = styleFamily
        self.appearance = appearance ?? HabitatThemeAppearance(
            category: category,
            styleFamily: styleFamily,
            background: "background.jpg",
            artFocus: HabitatThemeFocalPoint(x: 0.75, y: 0.5),
            safeSide: .leading,
            backgroundStrength: 0.42,
            panelOpacity: 0.88,
            blurRadius: 10,
            density: .comfortable
        )
        self.widgets = widgets
    }

    static let builtIn = BuiltInThemeCatalog.all.map(bundled)

    static func installed(_ package: InstalledPackage) -> HabitatThemeDescriptor {
        HabitatThemeDescriptor(
            id: package.id,
            name: package.manifest.name,
            detail: "\(package.manifest.author) · \(package.version)",
            symbol: "shippingbox.fill",
            surfaceHex: package.manifest.colors.surface,
            panelHex: package.manifest.colors.panel,
            panelAltHex: package.manifest.colors.panelAlt,
            textHex: package.manifest.colors.text,
            mutedTextHex: package.manifest.colors.mutedText,
            accentHex: package.manifest.colors.accent,
            secondaryHex: package.manifest.colors.secondary,
            highlightHex: package.manifest.colors.highlight,
            attentionHex: package.manifest.colors.attention,
            errorHex: package.manifest.colors.error,
            previewURL: package.url.appending(path: package.manifest.preview),
            backgroundURL: package.manifest.theme.map {
                package.url.appending(path: $0.background)
            },
            category: package.manifest.theme?.category ?? .custom,
            styleFamily: package.manifest.theme?.styleFamily ?? .gameCinematic,
            appearance: package.manifest.theme,
            widgets: package.manifest.widgets
        )
    }

    private static func bundled(_ definition: BuiltInThemeDefinition) -> HabitatThemeDescriptor {
        let directory = "Resources/Themes/\(definition.id)"
        let manifestURL = PackagedResourceLocator.url(
            forResource: "habitat",
            withExtension: "json",
            subdirectory: directory,
            packageBundleName: "CodexHabitat_CodexHabitatApp.bundle"
        )
        let manifest = manifestURL.flatMap { url in
            try? ManifestDecoder(runtimeVersion: "1.0.0").decode(Data(contentsOf: url))
        }
        return HabitatThemeDescriptor(
            id: definition.id,
            name: manifest?.name ?? definition.name,
            detail: definition.detail,
            symbol: definition.symbol,
            surfaceHex: manifest?.colors.surface ?? definition.palette.surface,
            panelHex: manifest?.colors.panel ?? definition.palette.panel,
            panelAltHex: manifest?.colors.panelAlt ?? definition.palette.panelAlt,
            textHex: manifest?.colors.text ?? definition.palette.text,
            mutedTextHex: manifest?.colors.mutedText ?? definition.palette.mutedText,
            accentHex: manifest?.colors.accent ?? definition.palette.accent,
            secondaryHex: manifest?.colors.secondary ?? definition.palette.secondary,
            highlightHex: manifest?.colors.highlight ?? definition.palette.highlight,
            attentionHex: manifest?.colors.attention ?? definition.palette.attention,
            errorHex: manifest?.colors.error ?? definition.palette.error,
            previewURL: PackagedResourceLocator.url(
                forResource: "preview",
                withExtension: "png",
                subdirectory: directory,
                packageBundleName: "CodexHabitat_CodexHabitatApp.bundle"
            ),
            backgroundURL: PackagedResourceLocator.url(
                forResource: "background",
                withExtension: "jpg",
                subdirectory: directory,
                packageBundleName: "CodexHabitat_CodexHabitatApp.bundle"
            ),
            category: manifest?.theme?.category ?? definition.category,
            styleFamily: manifest?.theme?.styleFamily ?? definition.styleFamily,
            appearance: manifest?.theme ?? definition.appearance(background: "background.jpg"),
            widgets: manifest?.widgets ?? []
        )
    }
}

struct HabitatPetPresentation: Equatable, Sendable {
    let renderMode: PetRenderMode
    let scale: Double
}

enum ResourceLibraryOperationState: Equatable, Sendable {
    case idle
    case importing
    case imported(String)
    case replacementRequired(String)
    case exporting
    case exported(String)
    case uninstalling
    case uninstalled(String)
    case failed
}

@MainActor
final class HabitatAppModel: ObservableObject {
    @Published private(set) var settings = HabitatSettings.default
    @Published private(set) var validPets: [PetLibraryEntry] = []
    @Published private(set) var petPresentations: [String: HabitatPetPresentation] = [:]
    @Published private(set) var installedPackages: [InstalledPackage] = []
    @Published private(set) var availableThemes = HabitatThemeDescriptor.builtIn
    @Published private(set) var resourceOperationState = ResourceLibraryOperationState.idle
    @Published private(set) var pendingReplacementArchiveURL: URL?
    @Published private(set) var onboardingStep = OnboardingStep.habitat
    var selectedSettingsSection = SettingsSection.habitat
    @Published private(set) var isLoaded = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var launchAtLoginStatus: HabitatLaunchAtLoginStatus
    @Published var isHabitatVisible = true

    let requiresAccount = false

    private let settingsStore: SettingsStore
    private let petRoot: URL
    private let resourceLibraryRoot: URL?
    private let launchAtLoginController: any HabitatLaunchAtLoginControlling
    private var saveTask: Task<Void, Never>?

    var requiresOnboarding: Bool { !settings.onboardingCompleted }
    var selectedTheme: HabitatThemeDescriptor {
        availableThemes.first(where: { $0.id == settings.selectedThemeID })
            ?? HabitatThemeDescriptor.builtIn[0]
    }
    var selectedThemeSupportsCodexBridge: Bool {
        codexBridgeThemeIDs.contains(settings.selectedThemeID)
    }
    var codexBridgeThemeIDs: Set<String> {
        Set(BuiltInThemeCatalog.all.map(\.id)).union(
            installedPackages.compactMap { package in
                package.manifest.theme == nil ? nil : package.id
            }
        )
    }

    init(
        settingsStore: SettingsStore,
        petRoot: URL,
        resourceLibraryRoot: URL? = nil,
        launchAtLoginController: any HabitatLaunchAtLoginControlling = InMemoryHabitatLaunchAtLoginController()
    ) {
        self.settingsStore = settingsStore
        self.petRoot = petRoot
        self.resourceLibraryRoot = resourceLibraryRoot
        self.launchAtLoginController = launchAtLoginController
        launchAtLoginStatus = launchAtLoginController.status
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
            resourceLibraryRoot: root.appending(path: "Library", directoryHint: .isDirectory),
            launchAtLoginController: SystemHabitatLaunchAtLoginController()
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

        reloadInstalledPackages()
        reloadPets()
        let validPetIDs = Set(validPets.compactMap(\.manifest?.id))
        var repairedSettings = normalized(settings)
        launchAtLoginStatus = launchAtLoginController.status
        if repairedSettings.launchAtLogin && launchAtLoginStatus == .disabled {
            launchAtLoginStatus = (try? launchAtLoginController.setEnabled(true))
                ?? launchAtLoginController.status
        }
        repairedSettings.launchAtLogin = launchAtLoginStatus.isRequested
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
        reloadPets()
        let validIDs = Set(validPets.compactMap(\.manifest?.id))
        if settings.selectedPetID.map(validIDs.contains) != true {
            updateSettings { $0.selectedPetID = validPets.first?.manifest?.id }
        }
    }

    func refreshResources() {
        reloadInstalledPackages()
        reloadPets()
        reconcileResourceSelections()
    }

    func makeThemeStudioModel() -> ThemeStudioModel? {
        guard let resourceLibraryRoot else { return nil }
        let pets = validPets.compactMap { entry -> ThemeStudioPetOption? in
            guard let manifest = entry.manifest else { return nil }
            return ThemeStudioPetOption(id: manifest.id, name: manifest.displayName)
        }
        return ThemeStudioModel(
            libraryRoot: resourceLibraryRoot,
            workingRoot: resourceLibraryRoot.appending(
                path: ".theme-studio",
                directoryHint: .isDirectory
            ),
            availablePets: pets
        )
    }

    func selectPet(_ id: String?) {
        let validIDs = Set(validPets.compactMap(\.manifest?.id))
        guard id == nil || id.map(validIDs.contains) == true else { return }
        updateSettings { $0.selectedPetID = id }
    }

    func selectTheme(_ id: String) {
        guard availableThemes.contains(where: { $0.id == id }) else { return }
        updateSettings { $0.selectedThemeID = id }
    }

    func importResourcePackage(from archiveURL: URL, replacing: Bool = false) async {
        guard let resourceLibraryRoot else {
            resourceOperationState = .failed
            return
        }
        pendingReplacementArchiveURL = nil
        resourceOperationState = .importing
        do {
            let package = try await Task.detached {
                try PackageInstaller(
                    libraryRoot: resourceLibraryRoot,
                    runtimeVersion: "1.0.0"
                ).install(archiveURL, replacing: replacing)
            }.value
            refreshResources()
            resourceOperationState = .imported(package.manifest.name)
        } catch PackageInstallationError.alreadyInstalled {
            pendingReplacementArchiveURL = archiveURL
            resourceOperationState = .replacementRequired(archiveURL.lastPathComponent)
        } catch {
            resourceOperationState = .failed
        }
    }

    func replacePendingResourcePackage() async {
        guard let pendingReplacementArchiveURL else { return }
        await importResourcePackage(from: pendingReplacementArchiveURL, replacing: true)
    }

    func cancelPendingResourceReplacement() {
        pendingReplacementArchiveURL = nil
        resourceOperationState = .idle
    }

    func exportResourcePackage(id: String, to destination: URL) async {
        guard let resourceLibraryRoot else {
            resourceOperationState = .failed
            return
        }
        resourceOperationState = .exporting
        do {
            try await Task.detached {
                try InstalledPackageLibrary(
                    root: resourceLibraryRoot,
                    runtimeVersion: "1.0.0"
                ).export(packageID: id, to: destination)
            }.value
            let name = installedPackages.first(where: { $0.id == id })?.manifest.name ?? id
            resourceOperationState = .exported(name)
        } catch {
            resourceOperationState = .failed
        }
    }

    func uninstallResourcePackage(id: String) async {
        guard let resourceLibraryRoot else {
            resourceOperationState = .failed
            return
        }
        resourceOperationState = .uninstalling
        let name = installedPackages.first(where: { $0.id == id })?.manifest.name ?? id
        do {
            try await Task.detached {
                try InstalledPackageLibrary(
                    root: resourceLibraryRoot,
                    runtimeVersion: "1.0.0"
                ).uninstall(packageID: id)
            }.value
            refreshResources()
            resourceOperationState = .uninstalled(name)
        } catch {
            resourceOperationState = .failed
        }
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

    func setPositionLocked(_ locked: Bool) {
        updateSettings { $0.positionLocked = locked }
    }

    func setOverlayPosition(displayID: String, x: Double, y: Double) {
        guard !displayID.isEmpty else { return }
        let position = OverlayPosition(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1)
        )
        guard settings.overlayPositions[displayID] != position else { return }
        updateSettings { $0.overlayPositions[displayID] = position }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            launchAtLoginStatus = try launchAtLoginController.setEnabled(enabled)
            errorMessage = nil
        } catch {
            launchAtLoginStatus = launchAtLoginController.status
            errorMessage = "macOS could not update the login item."
        }
        let requested = launchAtLoginStatus.isRequested
        updateSettings { $0.launchAtLogin = requested }
    }

    func openLoginItemSettings() {
        launchAtLoginController.openSystemSettings()
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
        if !availableThemes.contains(where: { $0.id == result.selectedThemeID }) {
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

    private func reloadPets() {
        let discovery = discoverValidPets()
        petPresentations = discovery.presentations
        validPets = discovery.entries
    }

    private func discoverValidPets() -> (
        entries: [PetLibraryEntry],
        presentations: [String: HabitatPetPresentation]
    ) {
        let local = ((try? PetLibrary(root: petRoot).discover()) ?? [])
            .filter { $0.status == .valid }
        var result: [PetLibraryEntry] = []
        var presentations: [String: HabitatPetPresentation] = [:]
        var identifiers: Set<String> = []
        for entry in local {
            guard let id = entry.manifest?.id, identifiers.insert(id).inserted else { continue }
            result.append(entry)
        }

        guard let resourceLibraryRoot else { return (result, presentations) }
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
                presentations[adapter.id] = HabitatPetPresentation(
                    renderMode: adapter.rendering.petRenderMode,
                    scale: adapter.scale
                )
            }
        }
        return (result, presentations)
    }

    private func reloadInstalledPackages() {
        guard let resourceLibraryRoot else {
            installedPackages = []
            availableThemes = HabitatThemeDescriptor.builtIn
            return
        }
        installedPackages = InstalledPackageLibrary(
            root: resourceLibraryRoot,
            runtimeVersion: "1.0.0"
        ).currentPackages()
        let builtInIDs = Set(HabitatThemeDescriptor.builtIn.map(\.id))
        availableThemes = HabitatThemeDescriptor.builtIn + installedPackages
            .filter { !builtInIDs.contains($0.id) }
            .map(HabitatThemeDescriptor.installed)
    }

    private func reconcileResourceSelections() {
        let validPetIDs = Set(validPets.compactMap(\.manifest?.id))
        let validThemeIDs = Set(availableThemes.map(\.id))
        var repaired = settings
        if repaired.selectedPetID.map(validPetIDs.contains) != true {
            repaired.selectedPetID = validPets.first?.manifest?.id
        }
        if !validThemeIDs.contains(repaired.selectedThemeID) {
            repaired.selectedThemeID = HabitatSettings.default.selectedThemeID
        }
        guard repaired != settings else { return }
        updateSettings { settings in
            settings = repaired
        }
    }
}

private extension HabitatRendering {
    var petRenderMode: PetRenderMode {
        switch self {
        case .auto: .auto
        case .pixelated: .pixelated
        case .smooth: .smooth
        }
    }
}

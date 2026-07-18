import Foundation
import HabitatCore
import ResourceKit
import SwiftUI

enum ThemeStudioState: Equatable, Sendable {
    case editing
    case saving
    case validationFailure(String)
    case saved(String)
}

enum ThemePaletteRole: CaseIterable, Sendable {
    case surface
    case panel
    case panelAlt
    case text
    case mutedText
    case accent
    case secondary
    case highlight
    case attention
    case error
}

struct ThemeStudioPetOption: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

@MainActor
final class ThemeStudioModel: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name = "" { didSet { markDirty() } }
    @Published var author = "" { didSet { markDirty() } }
    @Published private(set) var sourceImageURL: URL?
    @Published private(set) var palette: HabitatThemePalette?
    @Published private(set) var category = HabitatThemeCategory.custom
    @Published private(set) var styleFamily = HabitatThemeStyleFamily.gameCinematic
    @Published private(set) var artFocus = HabitatThemeFocalPoint(x: 0.75, y: 0.5)
    @Published private(set) var safeSide = HabitatThemeSafeSide.leading
    @Published private(set) var backgroundStrength = 0.42
    @Published private(set) var panelOpacity = 0.88
    @Published private(set) var blurRadius = 10.0
    @Published private(set) var density = HabitatThemeDensity.comfortable
    @Published private(set) var homeMode = HabitatThemeHomeMode.quiet
    @Published private(set) var taskMode = HabitatThemeTaskMode.ambient
    @Published private(set) var chromeMaterial = HabitatThemeChromeMaterial.tinted
    @Published private(set) var homeStrength = 0.42
    @Published private(set) var taskStrength = 0.19
    @Published private(set) var sidebarOpacity = 0.88
    @Published private(set) var headerOpacity = 0.88
    @Published private(set) var composerOpacity = 0.88
    @Published private(set) var pairedPetID: String?
    @Published private(set) var state = ThemeStudioState.editing
    @Published private(set) var isDirty = false
    @Published var showsDiscardConfirmation = false
    @Published private(set) var nameValidationMessage: String?
    @Published private(set) var authorValidationMessage: String?
    @Published private(set) var imageValidationMessage: String?

    let libraryRoot: URL
    let workingRoot: URL
    let availablePets: [ThemeStudioPetOption]

    private var suppressDirtyTracking = false

    var previewAppearance: HabitatThemeAppearance {
        HabitatThemeAppearance(
            category: category,
            styleFamily: styleFamily,
            background: "background.jpg",
            artFocus: artFocus,
            safeSide: safeSide,
            backgroundStrength: backgroundStrength,
            panelOpacity: panelOpacity,
            blurRadius: blurRadius,
            density: density,
            homeMode: homeMode,
            taskMode: taskMode,
            chromeMaterial: chromeMaterial,
            homeStrength: homeStrength,
            taskStrength: taskStrength,
            sidebarOpacity: sidebarOpacity,
            headerOpacity: headerOpacity,
            composerOpacity: composerOpacity
        )
    }

    init(
        libraryRoot: URL,
        workingRoot: URL,
        availablePets: [ThemeStudioPetOption] = []
    ) {
        self.libraryRoot = libraryRoot
        self.workingRoot = workingRoot
        self.availablePets = availablePets
    }

    func selectImage(_ url: URL) throws {
        do {
            let suggested = try ThemePackageBuilder(workingRoot: workingRoot)
                .suggestPalette(from: url)
            sourceImageURL = url
            palette = suggested
            imageValidationMessage = nil
            markDirty()
        } catch {
            imageValidationMessage = L10n.text("Choose a valid local PNG, JPEG, or WebP image.")
            state = .validationFailure(imageValidationMessage ?? "")
            throw error
        }
    }

    func setPalette(_ value: HabitatThemePalette) {
        palette = value
        markDirty()
    }

    func setColor(_ role: ThemePaletteRole, hex: String) {
        guard let current = palette else { return }
        let value = hex.uppercased()
        let updated = HabitatThemePalette(
            surface: role == .surface ? value : current.surface,
            panel: role == .panel ? value : current.panel,
            panelAlt: role == .panelAlt ? value : current.panelAlt,
            text: role == .text ? value : current.text,
            mutedText: role == .mutedText ? value : current.mutedText,
            accent: role == .accent ? value : current.accent,
            secondary: role == .secondary ? value : current.secondary,
            highlight: role == .highlight ? value : current.highlight,
            attention: role == .attention ? value : current.attention,
            error: role == .error ? value : current.error
        )
        setPalette(updated)
    }

    func color(for role: ThemePaletteRole) -> String? {
        guard let palette else { return nil }
        return switch role {
        case .surface: palette.surface
        case .panel: palette.panel
        case .panelAlt: palette.panelAlt
        case .text: palette.text
        case .mutedText: palette.mutedText
        case .accent: palette.accent
        case .secondary: palette.secondary
        case .highlight: palette.highlight
        case .attention: palette.attention
        case .error: palette.error
        }
    }

    func setStyleFamily(_ value: HabitatThemeStyleFamily) {
        guard styleFamily != value else { return }
        styleFamily = value
        markDirty()
    }

    func setSafeSide(_ value: HabitatThemeSafeSide) {
        guard safeSide != value else { return }
        safeSide = value
        markDirty()
    }

    func setDensity(_ value: HabitatThemeDensity) {
        guard density != value else { return }
        density = value
        markDirty()
    }

    func setHomeMode(_ value: HabitatThemeHomeMode) {
        guard homeMode != value else { return }
        homeMode = value
        markDirty()
    }

    func setTaskMode(_ value: HabitatThemeTaskMode) {
        guard taskMode != value else { return }
        taskMode = value
        markDirty()
    }

    func setChromeMaterial(_ value: HabitatThemeChromeMaterial) {
        guard chromeMaterial != value else { return }
        chromeMaterial = value
        markDirty()
    }

    func setPairedPetID(_ value: String?) {
        guard value == nil || availablePets.contains(where: { $0.id == value }) else { return }
        guard pairedPetID != value else { return }
        pairedPetID = value
        markDirty()
    }

    func setBackgroundStrength(_ value: Double) {
        let value = min(max(value, 0.10), 0.70)
        guard backgroundStrength != value else { return }
        backgroundStrength = value
        markDirty()
    }

    func setPanelOpacity(_ value: Double) {
        let value = min(max(value, 0.65), 1.0)
        guard panelOpacity != value else { return }
        panelOpacity = value
        markDirty()
    }

    func setBlurRadius(_ value: Double) {
        let value = min(max(value, 0), 24)
        guard blurRadius != value else { return }
        blurRadius = value
        markDirty()
    }

    func setHomeStrength(_ value: Double) {
        setBounded(value, range: 0.10...0.85, keyPath: \ThemeStudioModel.homeStrength)
    }

    func setTaskStrength(_ value: Double) {
        setBounded(value, range: 0.10...0.85, keyPath: \ThemeStudioModel.taskStrength)
    }

    func setSidebarOpacity(_ value: Double) {
        setBounded(value, range: 0.40...1.0, keyPath: \ThemeStudioModel.sidebarOpacity)
    }

    func setHeaderOpacity(_ value: Double) {
        setBounded(value, range: 0.40...1.0, keyPath: \ThemeStudioModel.headerOpacity)
    }

    func setComposerOpacity(_ value: Double) {
        setBounded(value, range: 0.40...1.0, keyPath: \ThemeStudioModel.composerOpacity)
    }

    func setArtFocus(x: Double, y: Double) {
        let value = HabitatThemeFocalPoint(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1)
        )
        guard artFocus != value else { return }
        artFocus = value
        markDirty()
    }

    func requestClose() -> Bool {
        guard isDirty else { return true }
        showsDiscardConfirmation = true
        return false
    }

    func discardDraft() {
        suppressDirtyTracking = true
        name = ""
        author = ""
        sourceImageURL = nil
        palette = nil
        category = .custom
        styleFamily = .gameCinematic
        artFocus = HabitatThemeFocalPoint(x: 0.75, y: 0.5)
        safeSide = .leading
        backgroundStrength = 0.42
        panelOpacity = 0.88
        blurRadius = 10
        density = .comfortable
        homeMode = .quiet
        taskMode = .ambient
        chromeMaterial = .tinted
        homeStrength = 0.42
        taskStrength = 0.19
        sidebarOpacity = 0.88
        headerOpacity = 0.88
        composerOpacity = 0.88
        pairedPetID = nil
        state = .editing
        nameValidationMessage = nil
        authorValidationMessage = nil
        imageValidationMessage = nil
        isDirty = false
        showsDiscardConfirmation = false
        suppressDirtyTracking = false
    }

    func saveLocally() async {
        guard let request = validatedRequest() else { return }
        state = .saving
        do {
            let libraryRoot = self.libraryRoot
            let workingRoot = self.workingRoot
            let installed = try await Task.detached {
                try ThemePackageBuilder(workingRoot: workingRoot).buildAndInstall(
                    request,
                    libraryRoot: libraryRoot,
                    replacing: true
                )
            }.value
            state = .saved(installed.id)
            isDirty = false
        } catch {
            state = .validationFailure(L10n.text("The theme could not be saved."))
        }
    }

    func export(to destination: URL) async {
        guard let request = validatedRequest() else { return }
        state = .saving
        do {
            let workingRoot = self.workingRoot
            _ = try await Task.detached {
                try ThemePackageBuilder(workingRoot: workingRoot).build(request, to: destination)
            }.value
            state = .saved(ThemePackageBuilder.safeID(for: request.name))
            isDirty = false
        } catch {
            state = .validationFailure(L10n.text("The theme could not be exported."))
        }
    }

    private func validatedRequest() -> ThemePackageRequest? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameIsValid = !trimmedName.isEmpty
            && trimmedName.count <= 100
            && !Self.containsControlCharacters(trimmedName)
        let authorIsValid = trimmedAuthor.count <= 100
            && !Self.containsControlCharacters(trimmedAuthor)
        if trimmedName.isEmpty {
            nameValidationMessage = L10n.text("Enter a theme name.")
        } else if !nameIsValid {
            nameValidationMessage = L10n.text(
                "Theme names must be 100 characters or fewer and contain no control characters."
            )
        } else {
            nameValidationMessage = nil
        }
        authorValidationMessage = authorIsValid
            ? nil
            : L10n.text(
                "Authors must be 100 characters or fewer and contain no control characters."
            )
        imageValidationMessage = sourceImageURL == nil
            ? L10n.text("Choose a local background image.")
            : nil
        guard nameIsValid,
              authorIsValid,
              let sourceImageURL,
              let palette
        else {
            state = .validationFailure(L10n.text("Fix the highlighted fields before saving."))
            return nil
        }
        return ThemePackageRequest(
            name: trimmedName,
            author: trimmedAuthor,
            sourceImageURL: sourceImageURL,
            palette: palette,
            category: category,
            styleFamily: styleFamily,
            artFocus: artFocus,
            safeSide: safeSide,
            backgroundStrength: backgroundStrength,
            panelOpacity: panelOpacity,
            blurRadius: blurRadius,
            density: density,
            homeMode: homeMode,
            taskMode: taskMode,
            chromeMaterial: chromeMaterial,
            homeStrength: homeStrength,
            taskStrength: taskStrength,
            sidebarOpacity: sidebarOpacity,
            headerOpacity: headerOpacity,
            composerOpacity: composerOpacity
        )
    }

    private static func containsControlCharacters(_ value: String) -> Bool {
        value.rangeOfCharacter(from: .controlCharacters) != nil
    }

    private func markDirty() {
        guard !suppressDirtyTracking else { return }
        isDirty = true
        if case .saving = state { return }
        state = .editing
    }

    private func setBounded(
        _ value: Double,
        range: ClosedRange<Double>,
        keyPath: ReferenceWritableKeyPath<ThemeStudioModel, Double>
    ) {
        let value = min(max(value, range.lowerBound), range.upperBound)
        guard self[keyPath: keyPath] != value else { return }
        self[keyPath: keyPath] = value
        markDirty()
    }
}

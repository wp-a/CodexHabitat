import Foundation
import HabitatCore
import ResourceKit
import SwiftUI

enum ThemeStudioState: Equatable, Sendable {
    case editing
    case saving
    case replacementRequired(String)
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

enum ThemeStudioMoodPreset: String, CaseIterable, Identifiable, Sendable {
    case obsidianGold
    case cyberNeon
    case frostedGlass
    case warmAtelier

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .obsidianGold: "Obsidian Gold"
        case .cyberNeon: "Cyber Neon"
        case .frostedGlass: "Frosted Glass"
        case .warmAtelier: "Warm Atelier"
        }
    }

    var accentHex: String {
        switch self {
        case .obsidianGold: "#E5B454"
        case .cyberNeon: "#22E6FF"
        case .frostedGlass: "#7DD3FC"
        case .warmAtelier: "#E07A5F"
        }
    }
}

struct ThemeStudioPetOption: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

struct ThemeStudioDraft: Equatable, Sendable {
    var name = ""
    var author = ""
    var sourceImageURL: URL?
    var palette: HabitatThemePalette?
    var category = HabitatThemeCategory.custom
    var styleFamily = HabitatThemeStyleFamily.gameCinematic
    var artFocus = HabitatThemeFocalPoint(x: 0.75, y: 0.5)
    var safeSide = HabitatThemeSafeSide.leading
    var backgroundStrength = 0.42
    var panelOpacity = 0.88
    var blurRadius = 10.0
    var density = HabitatThemeDensity.comfortable
    var homeMode = HabitatThemeHomeMode.quiet
    var taskMode = HabitatThemeTaskMode.ambient
    var chromeMaterial = HabitatThemeChromeMaterial.tinted
    var homeStrength = 0.42
    var taskStrength = 0.19
    var sidebarOpacity = 0.88
    var headerOpacity = 0.88
    var composerOpacity = 0.88
    var homeArtFocus = HabitatThemeFocalPoint(x: 0.75, y: 0.5)
    var taskArtFocus = HabitatThemeFocalPoint(x: 0.75, y: 0.5)
    var homeArtScale = 1.0
    var taskArtScale = 1.0
    var taskSidebarOpacity = 0.88
    var taskHeaderOpacity = 0.88
    var homeContentOpacity = 0.66
    var taskContentOpacity = 0.84
    var homeContentWidth = 0.56
    var vignetteStrength = 0.34
    var artSaturation = 0.92
    var artContrast = 0.96
    var artExposure = 0.98
    var localizedScrimStrength = 0.34
    var pairedPetID: String?
}

struct ThemeStudioOperations: Sendable {
    let suggestPalette: @Sendable (URL, URL) async throws -> HabitatThemePalette
    let install: @Sendable (ThemePackageRequest, URL, URL, Bool) async throws -> String
    let export: @Sendable (ThemePackageRequest, URL, URL) async throws -> Void

    static let live = ThemeStudioOperations(
        suggestPalette: { sourceURL, workingRoot in
            try await Task.detached(priority: .userInitiated) {
                try ThemePackageBuilder(workingRoot: workingRoot).suggestPalette(from: sourceURL)
            }.value
        },
        install: { request, libraryRoot, workingRoot, replacing in
            try await Task.detached(priority: .userInitiated) {
                try ThemePackageBuilder(workingRoot: workingRoot).buildAndInstall(
                    request,
                    libraryRoot: libraryRoot,
                    replacing: replacing
                ).id
            }.value
        },
        export: { request, destination, workingRoot in
            try await Task.detached(priority: .userInitiated) {
                _ = try ThemePackageBuilder(workingRoot: workingRoot).build(
                    request,
                    to: destination
                )
            }.value
        }
    )
}

enum ThemeFocalPointMapper {
    static func artworkRect(
        in canvasRect: CGRect,
        route: ThemeTreatmentPreviewRoute,
        taskMode: HabitatThemeTaskMode
    ) -> CGRect {
        guard route == .task, taskMode == .banner else { return canvasRect }
        return CGRect(
            x: canvasRect.minX,
            y: canvasRect.minY,
            width: canvasRect.width,
            height: canvasRect.height * ThemeTreatmentPreviewSceneMetrics.bannerArtworkFraction
        )
    }

    static func unitPoint(at point: CGPoint, in rect: CGRect) -> HabitatThemeFocalPoint {
        let rect = rect.standardized
        guard point.x.isFinite,
              point.y.isFinite,
              rect.origin.x.isFinite,
              rect.origin.y.isFinite,
              rect.width.isFinite,
              rect.height.isFinite,
              rect.width > 0,
              rect.height > 0
        else {
            return HabitatThemeFocalPoint(x: 0.5, y: 0.5)
        }
        return normalizedPoint(
            x: (point.x - rect.minX) / rect.width,
            y: (point.y - rect.minY) / rect.height
        )
    }

    static func normalizedPoint(x: Double, y: Double) -> HabitatThemeFocalPoint {
        HabitatThemeFocalPoint(x: quantize(x), y: quantize(y))
    }

    private static func quantize(_ value: Double) -> Double {
        guard value.isFinite else { return 0.5 }
        return (clamp(value) * 100).rounded(.toNearestOrAwayFromZero) / 100
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

enum ThemeStudioUnitValueFormatter {
    static func string(for value: Double) -> String {
        guard value.isFinite else { return "0.5" }
        return String(value)
    }
}

@MainActor
final class ThemeStudioModel: ObservableObject, Identifiable {
    let id = UUID()
    @Published private(set) var draft: ThemeStudioDraft
    @Published private(set) var state = ThemeStudioState.editing
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var isSelectingImage = false
    @Published var showsDiscardConfirmation = false
    @Published private(set) var nameValidationMessage: String?
    @Published private(set) var authorValidationMessage: String?
    @Published private(set) var imageValidationMessage: String?

    let libraryRoot: URL
    let workingRoot: URL
    let availablePets: [ThemeStudioPetOption]

    private var baselineDraft: ThemeStudioDraft
    private var undoStack: [ThemeStudioDraft] = []
    private var redoStack: [ThemeStudioDraft] = []
    private var continuousEditStart: ThemeStudioDraft?
    private var imageSelectionGeneration = 0
    private var persistenceGeneration = 0
    private var activePersistenceGeneration: Int?
    private let operations: ThemeStudioOperations
    private static let maximumHistoryCount = 50

    var name: String {
        get { draft.name }
        set { performEdit { $0.name = newValue } }
    }

    var author: String {
        get { draft.author }
        set { performEdit { $0.author = newValue } }
    }

    var sourceImageURL: URL? { draft.sourceImageURL }
    var palette: HabitatThemePalette? { draft.palette }
    var category: HabitatThemeCategory { draft.category }
    var styleFamily: HabitatThemeStyleFamily { draft.styleFamily }
    var artFocus: HabitatThemeFocalPoint { draft.artFocus }
    var safeSide: HabitatThemeSafeSide { draft.safeSide }
    var backgroundStrength: Double { draft.backgroundStrength }
    var panelOpacity: Double { draft.panelOpacity }
    var blurRadius: Double { draft.blurRadius }
    var density: HabitatThemeDensity { draft.density }
    var homeMode: HabitatThemeHomeMode { draft.homeMode }
    var taskMode: HabitatThemeTaskMode { draft.taskMode }
    var chromeMaterial: HabitatThemeChromeMaterial { draft.chromeMaterial }
    var homeStrength: Double { draft.homeStrength }
    var taskStrength: Double { draft.taskStrength }
    var sidebarOpacity: Double { draft.sidebarOpacity }
    var headerOpacity: Double { draft.headerOpacity }
    var composerOpacity: Double { draft.composerOpacity }
    var homeArtFocus: HabitatThemeFocalPoint { draft.homeArtFocus }
    var taskArtFocus: HabitatThemeFocalPoint { draft.taskArtFocus }
    var homeArtScale: Double { draft.homeArtScale }
    var taskArtScale: Double { draft.taskArtScale }
    var taskSidebarOpacity: Double { draft.taskSidebarOpacity }
    var taskHeaderOpacity: Double { draft.taskHeaderOpacity }
    var homeContentOpacity: Double { draft.homeContentOpacity }
    var taskContentOpacity: Double { draft.taskContentOpacity }
    var homeContentWidth: Double { draft.homeContentWidth }
    var vignetteStrength: Double { draft.vignetteStrength }
    var artSaturation: Double { draft.artSaturation }
    var artContrast: Double { draft.artContrast }
    var artExposure: Double { draft.artExposure }
    var localizedScrimStrength: Double { draft.localizedScrimStrength }
    var pairedPetID: String? { draft.pairedPetID }
    var isDirty: Bool { draft != baselineDraft }
    var canPersistDraft: Bool {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = draft.author.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
            && trimmedName.count <= 100
            && !Self.containsControlCharacters(trimmedName)
            && trimmedAuthor.count <= 100
            && !Self.containsControlCharacters(trimmedAuthor)
            && draft.sourceImageURL != nil
            && draft.palette != nil
    }

    var persistenceRequirementMessage: String? {
        guard !canPersistDraft else { return nil }
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = draft.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return L10n.text("Enter a theme name.")
        }
        if trimmedName.count > 100 || Self.containsControlCharacters(trimmedName) {
            return L10n.text(
                "Theme names must be 100 characters or fewer and contain no control characters."
            )
        }
        if trimmedAuthor.count > 100 || Self.containsControlCharacters(trimmedAuthor) {
            return L10n.text(
                "Authors must be 100 characters or fewer and contain no control characters."
            )
        }
        if draft.sourceImageURL == nil {
            return L10n.text("Choose a local background image.")
        }
        if draft.palette == nil {
            return L10n.text("Analyzing image")
        }
        return nil
    }

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
            composerOpacity: composerOpacity,
            homeArtFocus: homeArtFocus,
            taskArtFocus: taskArtFocus,
            homeArtScale: homeArtScale,
            taskArtScale: taskArtScale,
            taskSidebarOpacity: taskSidebarOpacity,
            taskHeaderOpacity: taskHeaderOpacity,
            homeContentOpacity: homeContentOpacity,
            taskContentOpacity: taskContentOpacity,
            homeContentWidth: homeContentWidth,
            vignetteStrength: vignetteStrength,
            artSaturation: artSaturation,
            artContrast: artContrast,
            artExposure: artExposure,
            localizedScrimStrength: localizedScrimStrength
        )
    }

    init(
        libraryRoot: URL,
        workingRoot: URL,
        availablePets: [ThemeStudioPetOption] = [],
        editing installedPackage: InstalledPackage? = nil,
        pairedPetID: String? = nil,
        operations: ThemeStudioOperations = .live
    ) {
        self.libraryRoot = libraryRoot
        self.workingRoot = workingRoot
        self.availablePets = availablePets
        self.operations = operations
        var initial = ThemeStudioDraft()
        if let pairedPetID, availablePets.contains(where: { $0.id == pairedPetID }) {
            initial.pairedPetID = pairedPetID
        }
        if let installedPackage,
           let appearance = installedPackage.manifest.theme {
            let colors = installedPackage.manifest.colors
            initial.name = installedPackage.manifest.name
            initial.author = installedPackage.manifest.author
            initial.sourceImageURL = installedPackage.url.appending(path: appearance.background)
            initial.palette = HabitatThemePalette(
                surface: colors.surface,
                panel: colors.panel ?? colors.surface,
                panelAlt: colors.panelAlt ?? colors.accent,
                text: colors.text,
                mutedText: colors.mutedText ?? colors.text,
                accent: colors.accent,
                secondary: colors.secondary ?? colors.attention,
                highlight: colors.highlight ?? colors.accent,
                attention: colors.attention,
                error: colors.error
            )
            initial.category = appearance.category
            initial.styleFamily = appearance.styleFamily
            initial.artFocus = appearance.artFocus
            initial.safeSide = appearance.safeSide
            initial.backgroundStrength = appearance.backgroundStrength
            initial.panelOpacity = appearance.panelOpacity
            initial.blurRadius = appearance.blurRadius
            initial.density = appearance.density
            initial.homeMode = appearance.resolvedHomeMode
            initial.taskMode = appearance.resolvedTaskMode
            initial.chromeMaterial = appearance.resolvedChromeMaterial
            initial.homeStrength = appearance.resolvedHomeStrength
            initial.taskStrength = appearance.resolvedTaskStrength
            initial.sidebarOpacity = appearance.resolvedSidebarOpacity
            initial.headerOpacity = appearance.resolvedHeaderOpacity
            initial.composerOpacity = appearance.resolvedComposerOpacity
            initial.homeArtFocus = appearance.resolvedHomeArtFocus
            initial.taskArtFocus = appearance.resolvedTaskArtFocus
            initial.homeArtScale = appearance.resolvedHomeArtScale
            initial.taskArtScale = appearance.resolvedTaskArtScale
            initial.taskSidebarOpacity = appearance.resolvedTaskSidebarOpacity
            initial.taskHeaderOpacity = appearance.resolvedTaskHeaderOpacity
            initial.homeContentOpacity = appearance.resolvedHomeContentOpacity
            initial.taskContentOpacity = appearance.resolvedTaskContentOpacity
            initial.homeContentWidth = appearance.resolvedHomeContentWidth
            initial.vignetteStrength = appearance.resolvedVignetteStrength
            initial.artSaturation = appearance.resolvedArtSaturation
            initial.artContrast = appearance.resolvedArtContrast
            initial.artExposure = appearance.resolvedArtExposure
            initial.localizedScrimStrength = appearance.resolvedLocalizedScrimStrength
        }
        draft = initial
        baselineDraft = initial
    }

    func selectImage(_ url: URL) async throws {
        guard activePersistenceGeneration == nil else { return }
        imageSelectionGeneration &+= 1
        let generation = imageSelectionGeneration
        isSelectingImage = true
        let workingRoot = self.workingRoot
        do {
            let suggested = try await operations.suggestPalette(url, workingRoot)
            guard finishImageSelection(generation) else { return }
            performEdit {
                $0.sourceImageURL = url
                $0.palette = suggested
            }
            imageValidationMessage = nil
        } catch {
            guard finishImageSelection(generation) else { return }
            imageValidationMessage = L10n.text("Choose a valid local PNG, JPEG, or WebP image.")
            state = .validationFailure(imageValidationMessage ?? "")
            throw error
        }
    }

    func setPalette(_ value: HabitatThemePalette) {
        performEdit { $0.palette = value }
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

    func setCategory(_ value: HabitatThemeCategory) {
        performEdit { $0.category = value }
    }

    func setStyleFamily(_ value: HabitatThemeStyleFamily) {
        performEdit { $0.styleFamily = value }
    }

    func setSafeSide(_ value: HabitatThemeSafeSide) {
        performEdit { $0.safeSide = value }
    }

    func setDensity(_ value: HabitatThemeDensity) {
        performEdit { $0.density = value }
    }

    func setHomeMode(_ value: HabitatThemeHomeMode) {
        performEdit { $0.homeMode = value }
    }

    func setTaskMode(_ value: HabitatThemeTaskMode) {
        performEdit { $0.taskMode = value }
    }

    func setChromeMaterial(_ value: HabitatThemeChromeMaterial) {
        performEdit { $0.chromeMaterial = value }
    }

    func setPairedPetID(_ value: String?) {
        guard value == nil || availablePets.contains(where: { $0.id == value }) else { return }
        performEdit { $0.pairedPetID = value }
    }

    func setBackgroundStrength(_ value: Double) {
        setBounded(value, range: 0.10...0.70, keyPath: \ThemeStudioDraft.backgroundStrength)
    }

    func setPanelOpacity(_ value: Double) {
        setBounded(value, range: 0.65...1.0, keyPath: \ThemeStudioDraft.panelOpacity)
    }

    func setBlurRadius(_ value: Double) {
        setBounded(value, range: 0...24, keyPath: \ThemeStudioDraft.blurRadius)
    }

    func setHomeStrength(_ value: Double) {
        setBounded(value, range: 0.10...0.85, keyPath: \ThemeStudioDraft.homeStrength)
    }

    func setTaskStrength(_ value: Double) {
        setBounded(value, range: 0.10...0.85, keyPath: \ThemeStudioDraft.taskStrength)
    }

    func setSidebarOpacity(_ value: Double) {
        setBounded(value, range: 0.40...1.0, keyPath: \ThemeStudioDraft.sidebarOpacity)
    }

    func setHeaderOpacity(_ value: Double) {
        setBounded(value, range: 0.0...1.0, keyPath: \ThemeStudioDraft.headerOpacity)
    }

    func setComposerOpacity(_ value: Double) {
        setBounded(value, range: 0.40...1.0, keyPath: \ThemeStudioDraft.composerOpacity)
    }

    func setHomeArtFocus(x: Double, y: Double) {
        setFocus(x: x, y: y, keyPath: \ThemeStudioDraft.homeArtFocus)
    }

    func setTaskArtFocus(x: Double, y: Double) {
        setFocus(x: x, y: y, keyPath: \ThemeStudioDraft.taskArtFocus)
    }

    func setHomeArtScale(_ value: Double) {
        setBounded(value, range: 1.00...1.35, keyPath: \ThemeStudioDraft.homeArtScale)
    }

    func setTaskArtScale(_ value: Double) {
        setBounded(value, range: 1.00...1.35, keyPath: \ThemeStudioDraft.taskArtScale)
    }

    func setTaskSidebarOpacity(_ value: Double) {
        setBounded(value, range: 0.54...0.90, keyPath: \ThemeStudioDraft.taskSidebarOpacity)
    }

    func setTaskHeaderOpacity(_ value: Double) {
        setBounded(value, range: 0.54...0.90, keyPath: \ThemeStudioDraft.taskHeaderOpacity)
    }

    func setHomeContentOpacity(_ value: Double) {
        setBounded(value, range: 0.40...0.78, keyPath: \ThemeStudioDraft.homeContentOpacity)
    }

    func setTaskContentOpacity(_ value: Double) {
        setBounded(value, range: 0.60...0.84, keyPath: \ThemeStudioDraft.taskContentOpacity)
    }

    func setHomeContentWidth(_ value: Double) {
        setBounded(value, range: 0.46...0.68, keyPath: \ThemeStudioDraft.homeContentWidth)
    }

    func setVignetteStrength(_ value: Double) {
        setBounded(value, range: 0.00...0.70, keyPath: \ThemeStudioDraft.vignetteStrength)
    }

    func applyMoodPreset(_ preset: ThemeStudioMoodPreset) {
        performEdit { draft in
            switch preset {
            case .obsidianGold:
                draft.styleFamily = .gameCinematic
                draft.chromeMaterial = .tinted
                draft.homeMode = .immersive
                draft.taskMode = .ambient
                draft.blurRadius = 12
                draft.homeStrength = 0.56
                draft.taskStrength = 0.24
                draft.vignetteStrength = 0.46
                draft.sidebarOpacity = 0.88
                draft.headerOpacity = 0.84
                if let existing = draft.palette {
                    draft.palette = HabitatThemePalette(
                        surface: "#0E1117",
                        panel: "#151A24",
                        panelAlt: "#222938",
                        text: "#F6F4EF",
                        mutedText: "#B2B7C4",
                        accent: "#E5B454",
                        secondary: "#F59E0B",
                        highlight: "#FDE68A",
                        attention: existing.attention,
                        error: existing.error
                    )
                }
            case .cyberNeon:
                draft.styleFamily = .arcade
                draft.chromeMaterial = .glass
                draft.homeMode = .immersive
                draft.taskMode = .banner
                draft.blurRadius = 16
                draft.homeStrength = 0.64
                draft.taskStrength = 0.34
                draft.vignetteStrength = 0.50
                draft.sidebarOpacity = 0.80
                draft.headerOpacity = 0.78
                if let existing = draft.palette {
                    draft.palette = HabitatThemePalette(
                        surface: "#090D18",
                        panel: "#10182B",
                        panelAlt: "#1B2845",
                        text: "#F0FAFF",
                        mutedText: "#9CB4CE",
                        accent: "#22E6FF",
                        secondary: "#FF4ECD",
                        highlight: "#8AF8FF",
                        attention: existing.attention,
                        error: existing.error
                    )
                }
            case .frostedGlass:
                draft.styleFamily = .cozyWorld
                draft.chromeMaterial = .glass
                draft.homeMode = .framed
                draft.taskMode = .ambient
                draft.blurRadius = 20
                draft.homeStrength = 0.48
                draft.taskStrength = 0.20
                draft.vignetteStrength = 0.22
                draft.sidebarOpacity = 0.76
                draft.headerOpacity = 0.72
                if let existing = draft.palette {
                    draft.palette = HabitatThemePalette(
                        surface: "#111A26",
                        panel: "#192638",
                        panelAlt: "#253750",
                        text: "#F4F9FF",
                        mutedText: "#AFC2D8",
                        accent: "#7DD3FC",
                        secondary: "#34D399",
                        highlight: "#BAE6FD",
                        attention: existing.attention,
                        error: existing.error
                    )
                }
            case .warmAtelier:
                draft.styleFamily = .classicDesktop
                draft.chromeMaterial = .solid
                draft.homeMode = .quiet
                draft.taskMode = .ambient
                draft.blurRadius = 6
                draft.homeStrength = 0.38
                draft.taskStrength = 0.16
                draft.vignetteStrength = 0.28
                draft.sidebarOpacity = 0.94
                draft.headerOpacity = 0.92
                if let existing = draft.palette {
                    draft.palette = HabitatThemePalette(
                        surface: "#1B1614",
                        panel: "#261F1C",
                        panelAlt: "#362C27",
                        text: "#FAF3EB",
                        mutedText: "#C7B8AA",
                        accent: "#E07A5F",
                        secondary: "#F2CC8F",
                        highlight: "#F4A261",
                        attention: existing.attention,
                        error: existing.error
                    )
                }
            }
        }
    }

    func setArtFocus(x: Double, y: Double) {
        setFocus(x: x, y: y, keyPath: \ThemeStudioDraft.artFocus)
    }

    func beginContinuousEdit() {
        if continuousEditStart != nil {
            endContinuousEdit()
        }
        continuousEditStart = draft
    }

    func endContinuousEdit() {
        guard let start = continuousEditStart else { return }
        continuousEditStart = nil
        guard start != draft else {
            updateHistoryAvailability()
            return
        }
        appendUndo(start)
        updateHistoryAvailability()
    }

    func undo() {
        endContinuousEdit()
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(draft)
        draft = previous
        if activePersistenceGeneration == nil {
            state = .editing
        }
        updateHistoryAvailability()
    }

    func redo() {
        endContinuousEdit()
        guard let next = redoStack.popLast() else { return }
        appendUndo(draft)
        draft = next
        if activePersistenceGeneration == nil {
            state = .editing
        }
        updateHistoryAvailability()
    }

    func requestClose() -> Bool {
        guard activePersistenceGeneration == nil else { return false }
        invalidateImageSelection()
        guard isDirty else { return true }
        showsDiscardConfirmation = true
        return false
    }

    func discardDraft() {
        guard activePersistenceGeneration == nil else { return }
        invalidateImageSelection()
        draft = baselineDraft
        continuousEditStart = nil
        undoStack.removeAll()
        redoStack.removeAll()
        state = .editing
        nameValidationMessage = nil
        authorValidationMessage = nil
        imageValidationMessage = nil
        showsDiscardConfirmation = false
        updateHistoryAvailability()
    }

    func saveLocally() async {
        await saveLocally(replacing: false)
    }

    func replaceExistingTheme() async {
        guard case .replacementRequired = state else { return }
        await saveLocally(replacing: true)
    }

    func cancelReplacement() {
        guard case .replacementRequired = state else { return }
        state = .editing
    }

    @discardableResult
    func validateDraftForPersistence() -> Bool {
        guard activePersistenceGeneration == nil, !isSelectingImage else { return false }
        endContinuousEdit()
        return validatedRequest(from: draft) != nil
    }

    private func saveLocally(replacing: Bool) async {
        guard activePersistenceGeneration == nil, !isSelectingImage else { return }
        invalidateImageSelection()
        endContinuousEdit()
        let savedDraft = draft
        guard let request = validatedRequest(from: savedDraft) else { return }
        let generation = beginPersistence()
        do {
            let installedID = try await operations.install(
                request,
                libraryRoot,
                workingRoot,
                replacing
            )
            guard finishPersistence(generation) else { return }
            completeSuccessfulOperation(savedDraft, id: installedID)
        } catch PackageInstallationError.alreadyInstalled {
            guard finishPersistence(generation) else { return }
            state = draft == savedDraft
                ? .replacementRequired(ThemePackageBuilder.safeID(for: request.name))
                : .editing
        } catch {
            guard finishPersistence(generation) else { return }
            state = .validationFailure(L10n.text("The theme could not be saved."))
        }
    }

    func export(to destination: URL) async {
        guard activePersistenceGeneration == nil, !isSelectingImage else { return }
        invalidateImageSelection()
        endContinuousEdit()
        let exportedDraft = draft
        guard let request = validatedRequest(from: exportedDraft) else { return }
        let generation = beginPersistence()
        do {
            try await operations.export(request, destination, workingRoot)
            guard finishPersistence(generation) else { return }
            completeSuccessfulOperation(
                exportedDraft,
                id: ThemePackageBuilder.safeID(for: request.name)
            )
        } catch {
            guard finishPersistence(generation) else { return }
            state = .validationFailure(L10n.text("The theme could not be exported."))
        }
    }

    private func validatedRequest(from draft: ThemeStudioDraft) -> ThemePackageRequest? {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = draft.author.trimmingCharacters(in: .whitespacesAndNewlines)
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
        imageValidationMessage = draft.sourceImageURL == nil
            ? L10n.text("Choose a local background image.")
            : nil
        guard nameIsValid,
              authorIsValid,
              let sourceImageURL = draft.sourceImageURL,
              let palette = draft.palette
        else {
            state = .validationFailure(L10n.text("Fix the highlighted fields before saving."))
            return nil
        }
        return ThemePackageRequest(
            name: trimmedName,
            author: trimmedAuthor,
            sourceImageURL: sourceImageURL,
            palette: palette,
            category: draft.category,
            styleFamily: draft.styleFamily,
            artFocus: draft.artFocus,
            safeSide: draft.safeSide,
            backgroundStrength: draft.backgroundStrength,
            panelOpacity: draft.panelOpacity,
            blurRadius: draft.blurRadius,
            density: draft.density,
            homeMode: draft.homeMode,
            taskMode: draft.taskMode,
            chromeMaterial: draft.chromeMaterial,
            homeStrength: draft.homeStrength,
            taskStrength: draft.taskStrength,
            sidebarOpacity: draft.sidebarOpacity,
            headerOpacity: draft.headerOpacity,
            composerOpacity: draft.composerOpacity,
            homeArtFocus: draft.homeArtFocus,
            taskArtFocus: draft.taskArtFocus,
            homeArtScale: draft.homeArtScale,
            taskArtScale: draft.taskArtScale,
            taskSidebarOpacity: draft.taskSidebarOpacity,
            taskHeaderOpacity: draft.taskHeaderOpacity,
            homeContentOpacity: draft.homeContentOpacity,
            taskContentOpacity: draft.taskContentOpacity,
            homeContentWidth: draft.homeContentWidth,
            vignetteStrength: draft.vignetteStrength,
            artSaturation: draft.artSaturation,
            artContrast: draft.artContrast,
            artExposure: draft.artExposure,
            localizedScrimStrength: draft.localizedScrimStrength
        )
    }

    private static func containsControlCharacters(_ value: String) -> Bool {
        value.rangeOfCharacter(from: .controlCharacters) != nil
    }

    private func setBounded(
        _ value: Double,
        range: ClosedRange<Double>,
        keyPath: WritableKeyPath<ThemeStudioDraft, Double>
    ) {
        let value = min(max(value, range.lowerBound), range.upperBound)
        performEdit { $0[keyPath: keyPath] = value }
    }

    private func setFocus(
        x: Double,
        y: Double,
        keyPath: WritableKeyPath<ThemeStudioDraft, HabitatThemeFocalPoint>
    ) {
        let value = ThemeFocalPointMapper.normalizedPoint(x: x, y: y)
        performEdit { $0[keyPath: keyPath] = value }
    }

    private func performEdit(_ edit: (inout ThemeStudioDraft) -> Void) {
        if continuousEditStart == nil {
            var updated = draft
            edit(&updated)
            guard updated != draft else { return }
            appendUndo(draft)
            redoStack.removeAll()
            draft = updated
        } else {
            var updated = draft
            edit(&updated)
            guard updated != draft else { return }
            redoStack.removeAll()
            draft = updated
        }
        if activePersistenceGeneration == nil {
            state = .editing
        }
        updateHistoryAvailability()
    }

    private func appendUndo(_ value: ThemeStudioDraft) {
        undoStack.append(value)
        if undoStack.count > Self.maximumHistoryCount {
            undoStack.removeFirst(undoStack.count - Self.maximumHistoryCount)
        }
    }

    private func updateHistoryAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func invalidateImageSelection() {
        imageSelectionGeneration &+= 1
        isSelectingImage = false
    }

    private func finishImageSelection(_ generation: Int) -> Bool {
        guard generation == imageSelectionGeneration else { return false }
        isSelectingImage = false
        return true
    }

    private func beginPersistence() -> Int {
        persistenceGeneration &+= 1
        activePersistenceGeneration = persistenceGeneration
        state = .saving
        return persistenceGeneration
    }

    private func finishPersistence(_ generation: Int) -> Bool {
        guard activePersistenceGeneration == generation else { return false }
        activePersistenceGeneration = nil
        return true
    }

    private func completeSuccessfulOperation(_ savedDraft: ThemeStudioDraft, id: String) {
        baselineDraft = savedDraft
        continuousEditStart = nil
        redoStack.removeAll()
        undoStack.removeAll()
        if draft != savedDraft {
            appendUndo(savedDraft)
        }
        state = draft == savedDraft ? .saved(id) : .editing
        updateHistoryAvailability()
    }
}

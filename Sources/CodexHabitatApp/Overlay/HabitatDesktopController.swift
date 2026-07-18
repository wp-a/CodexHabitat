import AppKit
import Combine
import HabitatCore
import OverlayHost
import PetRuntime
import SwiftUI
import WidgetRuntime

struct HabitatPetAsset {
    let id: String
    let renderer: SpriteSheetRenderer
    let availableRows: Set<Int>
    let presentation: HabitatPetPresentation
}

private struct HabitatPetAssetSource: Equatable {
    let entry: PetLibraryEntry
    let presentation: HabitatPetPresentation
    let fileSize: Int?
    let modificationDate: Date?

    init(entry: PetLibraryEntry, presentation: HabitatPetPresentation) {
        self.entry = entry
        self.presentation = presentation
        let attributes = entry.spritesheetURL.flatMap {
            try? FileManager.default.attributesOfItem(atPath: $0.path)
        }
        fileSize = (attributes?[.size] as? NSNumber)?.intValue
        modificationDate = attributes?[.modificationDate] as? Date
    }
}

private struct HabitatDesktopApplication {
    let settings: HabitatSettings
    let pets: [PetLibraryEntry]
    let petPresentations: [String: HabitatPetPresentation]
    let isVisible: Bool
    let themes: [HabitatThemeDescriptor]
}

private actor HabitatPetRendererWorker {
    private let loader: @Sendable (URL, PetAtlasMetadata) -> SpriteSheetRenderer

    init(
        loader: @escaping @Sendable (URL, PetAtlasMetadata) -> SpriteSheetRenderer
    ) {
        self.loader = loader
    }

    func load(
        contentsOf url: URL,
        atlas: PetAtlasMetadata
    ) -> SpriteSheetRenderer? {
        guard !Task.isCancelled else { return nil }
        let renderer = loader(url, atlas)
        guard !Task.isCancelled else { return nil }
        return renderer
    }
}

@MainActor
final class HabitatOverlayPresentation: ObservableObject {
    @Published var isWidgetRailExpanded = true {
        didSet {
            guard isWidgetRailExpanded != oldValue else { return }
            onExpansionChange?(isWidgetRailExpanded)
        }
    }

    var onExpansionChange: ((Bool) -> Void)?
}

@MainActor
final class HabitatDesktopController: ObservableObject {
    typealias PetRendererLoader = @Sendable (URL, PetAtlasMetadata) -> SpriteSheetRenderer

    private var overlay: OverlayController?
    private let presentation = HabitatOverlayPresentation()
    @Published private(set) var widgetModel = WidgetRailModel()
    @Published private(set) var currentSnapshot = HabitatSnapshot()
    @Published private(set) var isTemporaryMoveMode = false
    private var petModel: HabitatOverlayModel?
    private var cancellable: AnyCancellable?
    private weak var boundModel: HabitatAppModel?
    private var renderedPetID: String?
    private var renderedPetPresentation: HabitatPetPresentation?
    private var renderedWidgets: [WidgetIdentifier] = []
    private var renderedThemeID: String?
    private var renderedScale: Double?
    private var renderedReduceMotion: Bool?
    private let petRendererWorker: HabitatPetRendererWorker
    private var cachedPetAssetSource: HabitatPetAssetSource?
    private var cachedPetAsset: HabitatPetAsset?
    private var pendingPetAssetSource: HabitatPetAssetSource?
    private var petRendererLoadTask: Task<Void, Never>?
    private var latestApplication: HabitatDesktopApplication?
    private var storedClickThrough = false
    private var storedPositionLocked = false

    @Published private(set) var isVisible = false
    var currentThemeID: String? { renderedThemeID }
    var onOpenSettings: (() -> Void)?

    var isInteractive: Bool { overlay?.isInteractive ?? false }
    var isMovementEnabled: Bool { overlay?.isMovementEnabled ?? false }
    var currentPetSnapshot: HabitatSnapshot? { petModel?.snapshot }
    var currentPetRenderMode: PetRenderMode? { renderedPetPresentation?.renderMode }
    var currentPetScale: Double? { renderedPetPresentation?.scale }
    var currentPetReduceMotion: Bool? { petModel?.reduceMotion }
    var isPetAnimationActive: Bool { petModel?.isAnimationActive ?? false }
    var currentWidgetSnapshot: HabitatSnapshot { widgetModel.snapshot }
    var panelSize: CGSize {
        overlay?.panel.frame.size ?? HabitatOverlayLayout(
            isWidgetRailExpanded: presentation.isWidgetRailExpanded
        ).containerSize
    }
    var panelFrame: CGRect { overlay?.panel.frame ?? .zero }
    var dragRegionFrame: CGRect { overlay?.dragRegionFrame ?? .zero }

    init(
        isWidgetRailExpanded: Bool = true,
        petRendererLoader: @escaping PetRendererLoader = {
            SpriteSheetRenderer(contentsOf: $0, atlas: $1)
        }
    ) {
        petRendererWorker = HabitatPetRendererWorker(loader: petRendererLoader)
        presentation.isWidgetRailExpanded = isWidgetRailExpanded
        presentation.onExpansionChange = { [weak self] _ in
            let rightEdge = self?.overlay?.panel.frame.maxX
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.resizePanelForPresentation(rightEdgeAnchor: rightEdge)
            }
        }
    }

    func bind(to model: HabitatAppModel) {
        boundModel = model
        cancellable = model.$settings
            .combineLatest(model.$validPets, model.$petPresentations, model.$availableThemes)
            .combineLatest(model.$isHabitatVisible)
            .sink { [weak self] state, isVisible in
                let (settings, pets, petPresentations, themes) = state
                self?.apply(
                    settings: settings,
                    pets: pets,
                    petPresentations: petPresentations,
                    isVisible: isVisible,
                    themes: themes
                )
            }
    }

    func apply(
        settings: HabitatSettings,
        pets: [PetLibraryEntry],
        petPresentations: [String: HabitatPetPresentation] = [:],
        isVisible requestedVisibility: Bool,
        themes: [HabitatThemeDescriptor] = HabitatThemeDescriptor.builtIn
    ) {
        latestApplication = HabitatDesktopApplication(
            settings: settings,
            pets: pets,
            petPresentations: petPresentations,
            isVisible: requestedVisibility,
            themes: themes
        )
        let shouldShow = settings.onboardingCompleted && requestedVisibility
        guard shouldShow else {
            cancelPendingPetAssetLoad()
            endTemporaryMoveMode()
            petModel?.setAnimationActive(false)
            overlay?.hide()
            isVisible = false
            return
        }

        let scale = min(max(settings.scale, 0.75), 1.5)
        let petAsset = asset(
            id: settings.selectedPetID,
            pets: pets,
            presentations: petPresentations
        )
        let theme = themes.first(where: {
            $0.id == settings.selectedThemeID
        }) ?? HabitatThemeDescriptor.builtIn[0]
        let reduceMotion = resolvedReduceMotion(settings.reduceMotion)
        let layout = HabitatOverlayLayout(
            isWidgetRailExpanded: presentation.isWidgetRailExpanded
                && !settings.widgetOrder.isEmpty
        )
        let needsNewPanel = overlay == nil || renderedScale != scale
        let needsNewContent = needsNewPanel
            || renderedPetID != petAsset?.id
            || renderedPetPresentation != petAsset?.presentation
            || renderedWidgets != settings.widgetOrder
            || renderedThemeID != theme.id
            || renderedReduceMotion != reduceMotion
        let savedPlacement = needsNewPanel
            ? overlay?.currentPlacement() ?? Self.savedPlacement(from: settings.overlayPositions)
            : nil

        if needsNewPanel {
            overlay?.hide()
            overlay = OverlayController(panelSize: Self.scaledSize(layout.containerSize, scale: scale))
            overlay?.setDragFrame(Self.scaledFrame(layout.petFrame, scale: scale))
            overlay?.onPrimaryClick = { [weak presentation] in
                presentation?.isWidgetRailExpanded.toggle()
            }
            overlay?.onPlacementChange = { [weak self] placement in
                self?.boundModel?.setOverlayPosition(
                    displayID: placement.displayID,
                    x: placement.relativePosition.x,
                    y: placement.relativePosition.y
                )
                self?.endTemporaryMoveMode()
            }
        }
        if needsNewContent, let overlay {
            if renderedThemeID != theme.id {
                widgetModel = Self.widgetModel(for: theme, snapshot: currentSnapshot)
            }
            let petModel = HabitatOverlayModel(
                initialSnapshot: currentSnapshot,
                availableRows: petAsset?.availableRows ?? Set(0..<9),
                reduceMotion: reduceMotion
            )
            self.petModel = petModel
            overlay.setContent(HabitatDesktopView(
                presentation: presentation,
                widgetModel: widgetModel,
                petModel: petModel,
                petAsset: petAsset,
                petChoices: pets.compactMap { entry in
                    entry.manifest.map {
                        HabitatPetChoice(id: $0.id, name: $0.displayName)
                    }
                },
                selectedPetID: settings.selectedPetID,
                enabledWidgets: settings.widgetOrder,
                theme: theme,
                scale: scale,
                positionLocked: settings.positionLocked,
                onSelectPet: { [weak self] id in self?.boundModel?.selectPet(id) },
                onTogglePositionLock: { [weak self] in
                    guard let model = self?.boundModel else { return }
                    model.setPositionLocked(!model.settings.positionLocked)
                },
                onHide: { [weak self] in self?.boundModel?.isHabitatVisible = false },
                onOpenSettings: { [weak self] in self?.onOpenSettings?() }
            ))
        }

        renderedPetID = petAsset?.id
        renderedPetPresentation = petAsset?.presentation
        renderedWidgets = settings.widgetOrder
        renderedThemeID = theme.id
        renderedScale = scale
        renderedReduceMotion = reduceMotion
        resizePanelForPresentation()
        storedClickThrough = settings.clickThrough
        storedPositionLocked = settings.positionLocked
        applyInteractionState()
        petModel?.setAnimationActive(true)
        if !isVisible || needsNewPanel {
            overlay?.show(savedPlacement: savedPlacement ?? overlay?.currentPlacement())
        }
        isVisible = true
    }

    func beginTemporaryMoveMode() {
        guard isVisible, overlay != nil else { return }
        isTemporaryMoveMode = true
        applyInteractionState()
    }

    func endTemporaryMoveMode() {
        guard isTemporaryMoveMode else { return }
        isTemporaryMoveMode = false
        applyInteractionState()
    }

    func apply(snapshot: HabitatSnapshot) {
        currentSnapshot = snapshot
        petModel?.apply(snapshot)
        widgetModel.apply(snapshot)
    }

    func setWidgetRailExpanded(_ expanded: Bool) {
        presentation.isWidgetRailExpanded = expanded
    }

    private func asset(
        id: String?,
        pets: [PetLibraryEntry],
        presentations: [String: HabitatPetPresentation]
    ) -> HabitatPetAsset? {
        guard let entry = pets.first(where: { $0.manifest?.id == id }),
              let id = entry.manifest?.id,
              let spritesheetURL = entry.spritesheetURL,
              let atlas = entry.atlas
        else {
            cancelPendingPetAssetLoad()
            cachedPetAssetSource = nil
            cachedPetAsset = nil
            return nil
        }
        let source = HabitatPetAssetSource(
            entry: entry,
            presentation: presentations[id] ?? HabitatPetPresentation(
                renderMode: .auto,
                scale: 1
            )
        )
        if source == cachedPetAssetSource {
            cancelPendingPetAssetLoad()
            return cachedPetAsset
        }
        if source != pendingPetAssetSource {
            startPetAssetLoad(
                source: source,
                id: id,
                spritesheetURL: spritesheetURL,
                atlas: atlas
            )
        }
        return cachedPetAsset
    }

    private func startPetAssetLoad(
        source: HabitatPetAssetSource,
        id: String,
        spritesheetURL: URL,
        atlas: PetAtlasMetadata
    ) {
        cancelPendingPetAssetLoad()
        pendingPetAssetSource = source
        let worker = petRendererWorker
        petRendererLoadTask = Task { [weak self] in
            guard let renderer = await worker.load(
                contentsOf: spritesheetURL,
                atlas: atlas
            ), !Task.isCancelled,
                  let self,
                  self.pendingPetAssetSource == source
            else {
                return
            }
            self.cachedPetAssetSource = source
            self.cachedPetAsset = HabitatPetAsset(
                id: id,
                renderer: renderer,
                availableRows: Set(0..<min(atlas.rows, 9)),
                presentation: source.presentation
            )
            self.pendingPetAssetSource = nil
            self.petRendererLoadTask = nil
            guard let application = self.latestApplication else { return }
            self.apply(
                settings: application.settings,
                pets: application.pets,
                petPresentations: application.petPresentations,
                isVisible: application.isVisible,
                themes: application.themes
            )
        }
    }

    private func cancelPendingPetAssetLoad() {
        petRendererLoadTask?.cancel()
        petRendererLoadTask = nil
        pendingPetAssetSource = nil
    }

    private static func scaledSize(_ size: CGSize, scale: Double) -> CGSize {
        CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    private static func scaledFrame(_ frame: CGRect, scale: Double) -> CGRect {
        frame.applying(
            CGAffineTransform(scaleX: scale, y: scale)
        )
    }

    private func resizePanelForPresentation(rightEdgeAnchor: CGFloat? = nil) {
        guard let overlay, let scale = renderedScale else { return }
        let layout = HabitatOverlayLayout(
            isWidgetRailExpanded: presentation.isWidgetRailExpanded
                && !renderedWidgets.isEmpty
        )
        overlay.resize(
            to: Self.scaledSize(layout.containerSize, scale: scale),
            preservingRightEdge: true,
            rightEdgeAnchor: rightEdgeAnchor
        )
        overlay.setDragFrame(Self.scaledFrame(layout.petFrame, scale: scale))
    }

    private func applyInteractionState() {
        if isTemporaryMoveMode {
            overlay?.setInteractive(true)
            overlay?.setMovementLocked(false)
        } else {
            overlay?.setInteractive(!storedClickThrough)
            overlay?.setMovementLocked(storedPositionLocked)
        }
    }

    private static func savedPlacement(
        from positions: [String: OverlayPosition]
    ) -> SavedOverlayPlacement? {
        guard !positions.isEmpty else { return nil }
        let mainDisplayID = (NSScreen.main?.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber)?.stringValue
        let entry = mainDisplayID.flatMap { id in positions[id].map { (id, $0) } }
            ?? positions.sorted(by: { $0.key < $1.key }).first
        guard let (displayID, position) = entry else { return nil }
        return SavedOverlayPlacement(
            displayID: displayID,
            relativePosition: RelativeOverlayPosition(x: position.x, y: position.y)
        )
    }

    private static func widgetModel(
        for theme: HabitatThemeDescriptor,
        snapshot: HabitatSnapshot
    ) -> WidgetRailModel {
        var pomodoro = PomodoroConfiguration()
        var countdown = CountdownConfiguration()
        for widget in theme.widgets {
            switch widget.configuration {
            case let .pomodoro(configuration):
                pomodoro = PomodoroConfiguration(
                    focusSeconds: configuration.focusSeconds,
                    restSeconds: configuration.restSeconds
                )
            case let .countdown(configuration):
                countdown = CountdownConfiguration(
                    durationSeconds: configuration.durationSeconds
                )
            default:
                continue
            }
        }
        return WidgetRailModel(
            snapshot: snapshot,
            configuration: pomodoro,
            countdownConfiguration: countdown
        )
    }

    private func resolvedReduceMotion(_ preference: ReduceMotionPreference) -> Bool {
        switch preference {
        case .system:
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        case .reduce:
            true
        case .full:
            false
        }
    }
}

private struct HabitatPetChoice: Identifiable, Equatable {
    let id: String
    let name: String
}

private struct HabitatDesktopView: View {
    @ObservedObject var presentation: HabitatOverlayPresentation
    @ObservedObject var widgetModel: WidgetRailModel
    @ObservedObject var petModel: HabitatOverlayModel
    let petAsset: HabitatPetAsset?
    let petChoices: [HabitatPetChoice]
    let selectedPetID: String?
    let enabledWidgets: [WidgetIdentifier]
    let theme: HabitatThemeDescriptor
    let scale: Double
    let positionLocked: Bool
    let onSelectPet: (String) -> Void
    let onTogglePositionLock: () -> Void
    let onHide: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        baseContent
            .frame(
                width: layout.containerSize.width,
                height: layout.containerSize.height,
                alignment: .topLeading
            )
            .scaleEffect(scale, anchor: .topLeading)
            .frame(
                width: layout.containerSize.width * scale,
                height: layout.containerSize.height * scale,
                alignment: .topLeading
            )
    }

    private var layout: HabitatOverlayLayout {
        HabitatOverlayLayout(
            isWidgetRailExpanded: presentation.isWidgetRailExpanded
                && !enabledWidgets.isEmpty
        )
    }

    private var baseContent: some View {
        ZStack(alignment: .topLeading) {
            if presentation.isWidgetRailExpanded, !enabledWidgets.isEmpty {
                WidgetRailView(
                    model: widgetModel,
                    enabledWidgets: enabledWidgets,
                    theme: theme
                )
                    .offset(
                        x: layout.widgetRailFrame?.minX ?? 0,
                        y: layout.widgetRailFrame?.minY ?? 0
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            petView
                .frame(
                    width: HabitatOverlayLayout.petSize.width,
                    height: HabitatOverlayLayout.petSize.height
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    presentation.isWidgetRailExpanded.toggle()
                }
                .contextMenu {
                    if !petChoices.isEmpty {
                        Menu(L10n.text("Pet")) {
                            ForEach(petChoices) { pet in
                                Button {
                                    onSelectPet(pet.id)
                                } label: {
                                    Label(
                                        pet.name,
                                        systemImage: pet.id == selectedPetID
                                            ? "checkmark"
                                            : "pawprint"
                                    )
                                }
                            }
                        }
                    }
                    Button(action: onTogglePositionLock) {
                        Label(
                            L10n.text(positionLocked ? "Unlock Position" : "Lock Position"),
                            systemImage: positionLocked ? "lock.open" : "lock"
                        )
                    }
                    Divider()
                    Button(action: onHide) {
                        Label(L10n.text("Hide Habitat"), systemImage: "eye.slash")
                    }
                    Button(action: onOpenSettings) {
                        Label(L10n.text("Settings…"), systemImage: "gearshape")
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    presentation.isWidgetRailExpanded.toggle()
                }
                .accessibilityIdentifier("overlay.pet.toggle-widgets")
                .offset(x: layout.petFrame.minX, y: layout.petFrame.minY)
        }
    }

    @ViewBuilder
    private var petView: some View {
        if let petAsset {
            PetView(
                model: petModel,
                renderer: petAsset.renderer,
                renderMode: petAsset.presentation.renderMode,
                pixelArtHint: true
            )
            .scaleEffect(petAsset.presentation.scale)
            .frame(
                width: HabitatOverlayLayout.petSize.width,
                height: HabitatOverlayLayout.petSize.height
            )
            .clipped()
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(L10n.text("Codex Habitat pet unavailable"))
        }
    }
}

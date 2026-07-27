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

struct PetRendererFailure: Equatable, Sendable {
    let petID: String
    let message: String
}

enum HabitatWidgetRailTransitionStyle: Equatable, Sendable {
    case opacity
    case moveAndOpacity

    static func resolve(reduceMotion: Bool) -> Self {
        reduceMotion ? .opacity : .moveAndOpacity
    }
}

private struct HabitatPetAssetSource: Equatable {
    let entry: PetLibraryEntry
    let presentation: HabitatPetPresentation

    init(entry: PetLibraryEntry, presentation: HabitatPetPresentation) {
        self.entry = entry
        self.presentation = presentation
    }
}

private struct HabitatPetFileSignature: Equatable, Sendable {
    let fileSize: Int?
    let modificationDate: Date?

    init(url: URL) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        fileSize = (attributes?[.size] as? NSNumber)?.intValue
        modificationDate = attributes?[.modificationDate] as? Date
    }
}

private enum HabitatPetRendererLoad: Sendable {
    case unchanged(HabitatPetFileSignature)
    case loaded(SpriteSheetRenderer, HabitatPetFileSignature)
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
        atlas: PetAtlasMetadata,
        matching cachedSignature: HabitatPetFileSignature?
    ) -> HabitatPetRendererLoad? {
        guard !Task.isCancelled else { return nil }
        let signature = HabitatPetFileSignature(url: url)
        if cachedSignature == signature {
            return .unchanged(signature)
        }
        let renderer = loader(url, atlas)
        guard !Task.isCancelled else { return nil }
        return .loaded(renderer, signature)
    }
}

@MainActor
final class HabitatOverlayPresentation: ObservableObject {
    @Published var isWidgetRailExpanded: Bool
    @Published var containerWidth: CGFloat

    @Published var isPetPressed = false
    @Published var selectedPetID: String?
    @Published var positionLocked = false

    init(isWidgetRailExpanded: Bool) {
        self.isWidgetRailExpanded = isWidgetRailExpanded
        containerWidth = isWidgetRailExpanded
            ? HabitatOverlayLayout.expandedSize.width
            : HabitatOverlayLayout.collapsedSize.width
    }
}

@MainActor
final class HabitatDesktopController: ObservableObject {
    typealias PetRendererLoader = @Sendable (URL, PetAtlasMetadata) -> SpriteSheetRenderer

    private var overlay: OverlayController?
    private let presentation: HabitatOverlayPresentation
    @Published private(set) var widgetModel = WidgetRailModel()
    @Published private(set) var currentSnapshot = HabitatSnapshot()
    @Published private(set) var isTemporaryMoveMode = false
    @Published private(set) var petLoadFailure: PetRendererFailure?
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
    private var cachedPetFileSignature: HabitatPetFileSignature?
    private var pendingPetAssetSource: HabitatPetAssetSource?
    private var petRendererLoadTask: Task<Void, Never>?
    private var latestApplication: HabitatDesktopApplication?
    private var storedClickThrough = false
    private var storedPositionLocked = false
    private let expansionAnimationDuration: Double
    private let expansionFrameInterval: Double
    private var expansionTask: Task<Void, Never>?
    private var expansionGeneration = 0

    @Published private(set) var isVisible = false
    var currentThemeID: String? { renderedThemeID }
    var currentSelectedPetID: String? { presentation.selectedPetID }
    var petLoadError: String? { petLoadFailure?.message }
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
    var contentSize: CGSize { overlay?.panel.contentView?.bounds.size ?? .zero }
    var dragRegionFrame: CGRect { overlay?.dragRegionFrame ?? .zero }

    init(
        isWidgetRailExpanded: Bool = true,
        expansionAnimationDuration: Double = 0.18,
        expansionFrameInterval: Double = 1.0 / 60.0,
        petRendererLoader: @escaping PetRendererLoader = {
            SpriteSheetRenderer(contentsOf: $0, atlas: $1)
        }
    ) {
        presentation = HabitatOverlayPresentation(
            isWidgetRailExpanded: isWidgetRailExpanded
        )
        self.expansionAnimationDuration = max(0, expansionAnimationDuration)
        self.expansionFrameInterval = max(0.001, expansionFrameInterval)
        petRendererWorker = HabitatPetRendererWorker(loader: petRendererLoader)
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
        presentation.selectedPetID = settings.selectedPetID
        presentation.positionLocked = settings.positionLocked
        let shouldShow = settings.onboardingCompleted && requestedVisibility
        guard shouldShow else {
            cancelExpansionAnimation()
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
        let widgetsChanged = renderedWidgets != settings.widgetOrder
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
            cancelExpansionAnimation()
            presentation.containerWidth = layout.containerSize.width
            overlay?.hide()
            overlay = OverlayController(panelSize: Self.scaledSize(layout.containerSize, scale: scale))
            overlay?.setDragFrame(Self.scaledFrame(layout.petFrame, scale: scale))
            overlay?.onPrimaryClick = { [weak self] in
                self?.toggleWidgetRailExpansion()
            }
            overlay?.onPrimaryPressChange = { [weak presentation] pressed in
                presentation?.isPetPressed = pressed
            }
            overlay?.onPrimaryDragStart = { [weak self] in
                self?.handlePrimaryDragStart()
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
                enabledWidgets: settings.widgetOrder,
                theme: theme,
                scale: scale,
                onToggleWidgets: { [weak self] in self?.toggleWidgetRailExpansion() },
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
        if widgetsChanged, !needsNewPanel {
            cancelExpansionAnimation()
            presentation.containerWidth = layout.containerSize.width
        }
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
        guard presentation.isWidgetRailExpanded != expanded else { return }
        presentation.isWidgetRailExpanded = expanded
        animatePanelExpansion(to: expanded)
    }

    func handlePrimaryDragStart() {
        cancelExpansionAnimation()
        guard let overlay, let scale = renderedScale else { return }
        presentation.containerWidth = overlay.panel.frame.width / scale
    }

    func retryPetRendererLoad() {
        guard let failure = petLoadFailure,
              let application = latestApplication,
              application.settings.selectedPetID == failure.petID
        else {
            return
        }
        cancelPendingPetAssetLoad()
        petLoadFailure = nil
        apply(
            settings: application.settings,
            pets: application.pets,
            petPresentations: application.petPresentations,
            isVisible: application.isVisible,
            themes: application.themes
        )
    }

    private func toggleWidgetRailExpansion() {
        setWidgetRailExpanded(!presentation.isWidgetRailExpanded)
    }

    private func animatePanelExpansion(to expanded: Bool) {
        cancelExpansionAnimation()
        let targetWidth = expanded && !renderedWidgets.isEmpty
            ? HabitatOverlayLayout.expandedSize.width
            : HabitatOverlayLayout.collapsedSize.width
        let startWidth = presentation.containerWidth
        guard startWidth != targetWidth else { return }
        let rightEdge = overlay?.panel.frame.maxX
        let shouldReduceMotion = renderedReduceMotion ?? false
        guard expansionAnimationDuration > 0, !shouldReduceMotion else {
            applyContainerWidth(targetWidth, rightEdgeAnchor: rightEdge)
            return
        }

        let generation = expansionGeneration
        let duration = expansionAnimationDuration
        let interval = expansionFrameInterval
        expansionTask = Task { @MainActor [weak self] in
            let clock = ContinuousClock()
            let start = clock.now
            while true {
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                guard let self, self.expansionGeneration == generation else { return }
                let progress = min(1, (clock.now - start) / .seconds(duration))
                let eased = 1 - pow(1 - progress, 3)
                let width = progress >= 1
                    ? targetWidth
                    : startWidth + (targetWidth - startWidth) * eased
                self.applyContainerWidth(width, rightEdgeAnchor: rightEdge)
                if progress >= 1 {
                    self.expansionTask = nil
                    return
                }
            }
        }
    }

    private func cancelExpansionAnimation() {
        expansionGeneration += 1
        expansionTask?.cancel()
        expansionTask = nil
    }

    private func applyContainerWidth(
        _ width: CGFloat,
        rightEdgeAnchor: CGFloat?
    ) {
        guard let overlay, let scale = renderedScale else {
            presentation.containerWidth = width
            return
        }
        let containerSize = CGSize(width: width, height: HabitatOverlayLayout.petSize.height)
        let petFrame = CGRect(
            x: width - HabitatOverlayLayout.petSize.width,
            y: 0,
            width: HabitatOverlayLayout.petSize.width,
            height: HabitatOverlayLayout.petSize.height
        )
        overlay.resize(
            to: Self.scaledSize(containerSize, scale: scale),
            preservingRightEdge: true,
            rightEdgeAnchor: rightEdgeAnchor,
            pointerPolicy: .preserve
        )
        let effectiveWidth = overlay.panel.frame.width / scale
        let effectivePetFrame = CGRect(
            x: effectiveWidth - HabitatOverlayLayout.petSize.width,
            y: petFrame.minY,
            width: petFrame.width,
            height: petFrame.height
        )
        overlay.setDragFrame(Self.scaledFrame(effectivePetFrame, scale: scale))
        presentation.containerWidth = effectiveWidth
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
            cachedPetFileSignature = nil
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
            petLoadFailure = nil
            if pendingPetAssetSource != source {
                startPetAssetLoad(
                    source: source,
                    id: id,
                    spritesheetURL: spritesheetURL,
                    atlas: atlas,
                    matchingFileSignature: cachedPetFileSignature
                )
            }
            return cachedPetAsset
        }
        if source != pendingPetAssetSource {
            startPetAssetLoad(
                source: source,
                id: id,
                spritesheetURL: spritesheetURL,
                atlas: atlas,
                matchingFileSignature: nil
            )
        }
        return cachedPetAsset
    }

    private func startPetAssetLoad(
        source: HabitatPetAssetSource,
        id: String,
        spritesheetURL: URL,
        atlas: PetAtlasMetadata,
        matchingFileSignature: HabitatPetFileSignature?
    ) {
        cancelPendingPetAssetLoad()
        petLoadFailure = nil
        pendingPetAssetSource = source
        let worker = petRendererWorker
        petRendererLoadTask = Task { [weak self] in
            let result = await worker.load(
                contentsOf: spritesheetURL,
                atlas: atlas,
                matching: matchingFileSignature
            )
            guard !Task.isCancelled,
                  let self,
                  self.pendingPetAssetSource == source
            else {
                return
            }
            self.pendingPetAssetSource = nil
            self.petRendererLoadTask = nil
            guard let result else { return }
            switch result {
            case .unchanged:
                return
            case let .loaded(renderer, signature):
                guard renderer.isRenderable else {
                    self.petLoadFailure = PetRendererFailure(
                        petID: id,
                        message: L10n.text("Unable to load pet artwork")
                    )
                    return
                }
                self.cachedPetFileSignature = signature
                self.cachedPetAssetSource = source
                self.cachedPetAsset = HabitatPetAsset(
                    id: id,
                    renderer: renderer,
                    availableRows: Set(0..<min(atlas.rows, 9)),
                    presentation: source.presentation
                )
            }
            guard self.cachedPetAssetSource == source else {
                self.petLoadFailure = PetRendererFailure(
                    petID: id,
                    message: L10n.text("Unable to load pet artwork")
                )
                return
            }
            self.petLoadFailure = nil
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
        let width = renderedWidgets.isEmpty
            ? HabitatOverlayLayout.collapsedSize.width
            : presentation.containerWidth
        let containerSize = CGSize(width: width, height: HabitatOverlayLayout.petSize.height)
        let petFrame = CGRect(
            x: width - HabitatOverlayLayout.petSize.width,
            y: 0,
            width: HabitatOverlayLayout.petSize.width,
            height: HabitatOverlayLayout.petSize.height
        )
        overlay.resize(
            to: Self.scaledSize(containerSize, scale: scale),
            preservingRightEdge: true,
            rightEdgeAnchor: rightEdgeAnchor
        )
        let effectiveWidth = overlay.panel.frame.width / scale
        let effectivePetFrame = CGRect(
            x: effectiveWidth - HabitatOverlayLayout.petSize.width,
            y: petFrame.minY,
            width: petFrame.width,
            height: petFrame.height
        )
        overlay.setDragFrame(Self.scaledFrame(effectivePetFrame, scale: scale))
        presentation.containerWidth = effectiveWidth
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
    let enabledWidgets: [WidgetIdentifier]
    let theme: HabitatThemeDescriptor
    let scale: Double
    let onToggleWidgets: () -> Void
    let onSelectPet: (String) -> Void
    let onTogglePositionLock: () -> Void
    let onHide: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        baseContent
            .frame(
                width: presentation.containerWidth,
                height: HabitatOverlayLayout.petSize.height,
                alignment: .topLeading
            )
            .scaleEffect(scale, anchor: .topLeading)
            .frame(
                width: presentation.containerWidth * scale,
                height: HabitatOverlayLayout.petSize.height * scale,
                alignment: .topLeading
            )
    }

    private var petFrame: CGRect {
        CGRect(
            x: presentation.containerWidth - HabitatOverlayLayout.petSize.width,
            y: 0,
            width: HabitatOverlayLayout.petSize.width,
            height: HabitatOverlayLayout.petSize.height
        )
    }

    private var baseContent: some View {
        ZStack(alignment: .topLeading) {
            if presentation.containerWidth > HabitatOverlayLayout.collapsedSize.width,
               !enabledWidgets.isEmpty
            {
                WidgetRailView(
                    model: widgetModel,
                    enabledWidgets: enabledWidgets,
                    theme: theme
                )
                    .offset(
                        x: 4,
                        y: 4
                    )
                    .transition(widgetRailTransition)
            }

            petView
                .frame(
                    width: HabitatOverlayLayout.petSize.width,
                    height: HabitatOverlayLayout.petSize.height
                )
                .modifier(HabitatPetPressFeedback(
                    isPressed: presentation.isPetPressed,
                    reduceMotion: petModel.reduceMotion
                ))
                .contentShape(Rectangle())
                .contextMenu {
                    if !petChoices.isEmpty {
                        Menu(L10n.text("Pet")) {
                            ForEach(petChoices) { pet in
                                Button {
                                    onSelectPet(pet.id)
                                } label: {
                                    Label(
                                        pet.name,
                                        systemImage: pet.id == presentation.selectedPetID
                                            ? "checkmark"
                                            : "pawprint"
                                    )
                                }
                            }
                        }
                    }
                    Button(action: onTogglePositionLock) {
                        Label(
                            L10n.text(
                                presentation.positionLocked ? "Unlock Position" : "Lock Position"
                            ),
                            systemImage: presentation.positionLocked ? "lock.open" : "lock"
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
                    onToggleWidgets()
                }
                .accessibilityIdentifier("overlay.pet.toggle-widgets")
                .offset(x: petFrame.minX, y: petFrame.minY)
        }
    }

    private var widgetRailTransition: AnyTransition {
        switch HabitatWidgetRailTransitionStyle.resolve(reduceMotion: petModel.reduceMotion) {
        case .opacity:
            .opacity
        case .moveAndOpacity:
            .move(edge: .leading).combined(with: .opacity)
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

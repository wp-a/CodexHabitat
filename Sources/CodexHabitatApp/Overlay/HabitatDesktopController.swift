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

@MainActor
final class HabitatOverlayPresentation: ObservableObject {
    @Published var isWidgetRailExpanded = true
}

@MainActor
final class HabitatDesktopController: ObservableObject {
    private var overlay: OverlayController?
    private let presentation = HabitatOverlayPresentation()
    @Published private(set) var widgetModel = WidgetRailModel()
    @Published private(set) var currentSnapshot = HabitatSnapshot()
    private var petModel: HabitatOverlayModel?
    private var cancellable: AnyCancellable?
    private weak var boundModel: HabitatAppModel?
    private var renderedPetID: String?
    private var renderedPetPresentation: HabitatPetPresentation?
    private var renderedWidgets: [WidgetIdentifier] = []
    private var renderedThemeID: String?
    private var renderedScale: Double?

    private(set) var isVisible = false
    var currentThemeID: String? { renderedThemeID }
    var onOpenSettings: (() -> Void)?

    var isInteractive: Bool { overlay?.isInteractive ?? false }
    var currentPetSnapshot: HabitatSnapshot? { petModel?.snapshot }
    var currentPetRenderMode: PetRenderMode? { renderedPetPresentation?.renderMode }
    var currentPetScale: Double? { renderedPetPresentation?.scale }
    var currentWidgetSnapshot: HabitatSnapshot { widgetModel.snapshot }
    var panelSize: CGSize {
        overlay?.panel.frame.size ?? HabitatOverlayLayout.containerSize
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
        let shouldShow = settings.onboardingCompleted && requestedVisibility
        guard shouldShow else {
            overlay?.hide()
            isVisible = false
            return
        }

        let scale = min(max(settings.scale, 0.75), 1.5)
        let petAsset = Self.asset(
            id: settings.selectedPetID,
            pets: pets,
            presentations: petPresentations
        )
        let theme = themes.first(where: {
            $0.id == settings.selectedThemeID
        }) ?? HabitatThemeDescriptor.builtIn[0]
        let needsNewPanel = overlay == nil || renderedScale != scale
        let needsNewContent = needsNewPanel
            || renderedPetID != petAsset?.id
            || renderedPetPresentation != petAsset?.presentation
            || renderedWidgets != settings.widgetOrder
            || renderedThemeID != theme.id
        let savedPlacement = needsNewPanel
            ? overlay?.currentPlacement() ?? Self.savedPlacement(from: settings.overlayPositions)
            : nil

        if needsNewPanel {
            overlay?.hide()
            overlay = OverlayController(panelSize: Self.scaledPanelSize(scale: scale))
            overlay?.onPlacementChange = { [weak self] placement in
                self?.boundModel?.setOverlayPosition(
                    displayID: placement.displayID,
                    x: placement.relativePosition.x,
                    y: placement.relativePosition.y
                )
            }
        }
        if needsNewContent, let overlay {
            if renderedThemeID != theme.id {
                widgetModel = Self.widgetModel(for: theme, snapshot: currentSnapshot)
            }
            let petModel = HabitatOverlayModel(
                initialSnapshot: currentSnapshot,
                availableRows: petAsset?.availableRows ?? Set(0..<9),
                reduceMotion: resolvedReduceMotion(settings.reduceMotion)
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
        overlay?.setInteractive(!settings.clickThrough)
        overlay?.setMovementLocked(settings.positionLocked)
        if !isVisible || needsNewPanel {
            overlay?.show(savedPlacement: savedPlacement ?? overlay?.currentPlacement())
        }
        isVisible = true
    }

    func apply(snapshot: HabitatSnapshot) {
        currentSnapshot = snapshot
        petModel?.apply(snapshot)
        widgetModel.apply(snapshot)
    }

    private static func asset(
        id: String?,
        pets: [PetLibraryEntry],
        presentations: [String: HabitatPetPresentation]
    ) -> HabitatPetAsset? {
        guard let entry = pets.first(where: { $0.manifest?.id == id }),
              let id = entry.manifest?.id,
              let spritesheetURL = entry.spritesheetURL,
              let atlas = entry.atlas
        else {
            return nil
        }
        return HabitatPetAsset(
            id: id,
            renderer: SpriteSheetRenderer(contentsOf: spritesheetURL, atlas: atlas),
            availableRows: Set(0..<min(atlas.rows, 9)),
            presentation: presentations[id] ?? HabitatPetPresentation(
                renderMode: .auto,
                scale: 1
            )
        )
    }

    private static func scaledPanelSize(scale: Double) -> CGSize {
        CGSize(
            width: HabitatOverlayLayout.containerSize.width * scale,
            height: HabitatOverlayLayout.containerSize.height * scale
        )
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
                width: HabitatOverlayLayout.containerSize.width,
                height: HabitatOverlayLayout.containerSize.height,
                alignment: .topLeading
            )
            .scaleEffect(scale, anchor: .topLeading)
            .frame(
                width: HabitatOverlayLayout.containerSize.width * scale,
                height: HabitatOverlayLayout.containerSize.height * scale,
                alignment: .topLeading
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
                    .offset(x: 4, y: 4)
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
                        Menu("Pet") {
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
                            positionLocked ? "Unlock Position" : "Lock Position",
                            systemImage: positionLocked ? "lock.open" : "lock"
                        )
                    }
                    Divider()
                    Button(action: onHide) {
                        Label("Hide Habitat", systemImage: "eye.slash")
                    }
                    Button(action: onOpenSettings) {
                        Label("Settings…", systemImage: "gearshape")
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    presentation.isWidgetRailExpanded.toggle()
                }
                .accessibilityIdentifier("overlay.pet.toggle-widgets")
                .offset(x: 200)
        }
        .animation(.snappy(duration: 0.22), value: presentation.isWidgetRailExpanded)
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
                .accessibilityLabel("Codex Habitat pet unavailable")
        }
    }
}

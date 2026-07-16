import Combine
import HabitatCore
import OverlayHost
import PetRuntime
import SwiftUI

struct HabitatPetAsset {
    let id: String
    let renderer: SpriteSheetRenderer
    let availableRows: Set<Int>
}

@MainActor
final class HabitatOverlayPresentation: ObservableObject {
    @Published var isWidgetRailExpanded = true
}

@MainActor
final class HabitatDesktopController {
    private var overlay: OverlayController?
    private let presentation = HabitatOverlayPresentation()
    private let widgetModel = WidgetRailModel()
    private var cancellable: AnyCancellable?
    private var renderedPetID: String?
    private var renderedWidgets: [WidgetIdentifier] = []
    private var renderedThemeID: String?
    private var renderedScale: Double?

    private(set) var isVisible = false

    var isInteractive: Bool { overlay?.isInteractive ?? false }
    var panelSize: CGSize {
        overlay?.panel.frame.size ?? HabitatOverlayLayout.containerSize
    }

    func bind(to model: HabitatAppModel) {
        cancellable = model.$settings
            .combineLatest(model.$validPets, model.$isHabitatVisible)
            .sink { [weak self] settings, pets, isVisible in
                self?.apply(settings: settings, pets: pets, isVisible: isVisible)
            }
    }

    func apply(
        settings: HabitatSettings,
        pets: [PetLibraryEntry],
        isVisible requestedVisibility: Bool
    ) {
        let shouldShow = settings.onboardingCompleted && requestedVisibility
        guard shouldShow else {
            overlay?.hide()
            isVisible = false
            return
        }

        let scale = min(max(settings.scale, 0.75), 1.5)
        let petAsset = Self.asset(id: settings.selectedPetID, pets: pets)
        let theme = HabitatThemeDescriptor.builtIn.first(where: {
            $0.id == settings.selectedThemeID
        }) ?? HabitatThemeDescriptor.builtIn[0]
        let needsNewPanel = overlay == nil || renderedScale != scale
        let needsNewContent = needsNewPanel
            || renderedPetID != petAsset?.id
            || renderedWidgets != settings.widgetOrder
            || renderedThemeID != theme.id
        let savedPlacement = needsNewPanel ? overlay?.currentPlacement() : nil

        if needsNewPanel {
            overlay?.hide()
            overlay = OverlayController(panelSize: Self.scaledPanelSize(scale: scale))
        }
        if needsNewContent, let overlay {
            let petModel = HabitatOverlayModel(
                initialSnapshot: HabitatSnapshot(activity: .offline, connectionHealth: .offline),
                availableRows: petAsset?.availableRows ?? Set(0..<9),
                reduceMotion: resolvedReduceMotion(settings.reduceMotion)
            )
            overlay.setContent(HabitatDesktopView(
                presentation: presentation,
                widgetModel: widgetModel,
                petModel: petModel,
                petAsset: petAsset,
                enabledWidgets: settings.widgetOrder,
                theme: theme,
                scale: scale
            ))
        }

        renderedPetID = petAsset?.id
        renderedWidgets = settings.widgetOrder
        renderedThemeID = theme.id
        renderedScale = scale
        overlay?.setInteractive(!settings.clickThrough)
        if !isVisible || needsNewPanel {
            overlay?.show(savedPlacement: savedPlacement ?? overlay?.currentPlacement())
        }
        isVisible = true
    }

    private static func asset(
        id: String?,
        pets: [PetLibraryEntry]
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
            availableRows: Set(0..<min(atlas.rows, 9))
        )
    }

    private static func scaledPanelSize(scale: Double) -> CGSize {
        CGSize(
            width: HabitatOverlayLayout.containerSize.width * scale,
            height: HabitatOverlayLayout.containerSize.height * scale
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

private struct HabitatDesktopView: View {
    @ObservedObject var presentation: HabitatOverlayPresentation
    @ObservedObject var widgetModel: WidgetRailModel
    @ObservedObject var petModel: HabitatOverlayModel
    let petAsset: HabitatPetAsset?
    let enabledWidgets: [WidgetIdentifier]
    let theme: HabitatThemeDescriptor
    let scale: Double

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
                renderMode: .auto,
                pixelArtHint: true
            )
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Codex Habitat pet unavailable")
        }
    }
}

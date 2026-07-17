import AppKit
import HabitatCore
import OverlayHost
import PetRuntime
import SwiftUI

@MainActor
enum OverlayPreview {
    private static var coordinator: OverlayPreviewCoordinator?

    static func run(themeID: String? = nil) {
        let coordinator = OverlayPreviewCoordinator(themeID: themeID)
        self.coordinator = coordinator
        coordinator.run()
    }
}

@MainActor
private final class OverlayPreviewCoordinator: NSObject {
    private let overlay = OverlayController(panelSize: HabitatOverlayLayout.containerSize)
    private let presentation = OverlayPreviewPresentation()
    private let widgetModel = WidgetRailModel(snapshot: HabitatSnapshot(
        activity: .working,
        connectionHealth: .online,
        primaryRateLimit: RateLimitSummary(usedPercent: 37, resetAt: nil)
    ))
    private let petAsset: OverlayPreviewPetAsset?
    private let petModel: HabitatOverlayModel
    private let theme: HabitatThemeDescriptor
    private var statusItem: NSStatusItem?
    private var interactionItem: NSMenuItem?
    private var widgetItem: NSMenuItem?

    init(themeID: String?) {
        let petAsset = themeID == nil ? Self.loadPetAsset() : nil
        self.petAsset = petAsset
        theme = HabitatThemeDescriptor.builtIn.first(where: { $0.id == themeID })
            ?? HabitatThemeDescriptor.builtIn[0]
        petModel = HabitatOverlayModel(
            initialSnapshot: HabitatSnapshot(activity: .working, connectionHealth: .online),
            availableRows: petAsset?.availableRows ?? Set(0..<9),
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        super.init()
    }

    func run() {
        NSApplication.shared.setActivationPolicy(.accessory)
        overlay.setContent(OverlayPreviewView(
            presentation: presentation,
            widgetModel: widgetModel,
            petModel: petModel,
            petAsset: petAsset,
            theme: theme
        ))
        overlay.setInteractive(true)
        overlay.show()
        installStatusItem()
        NSApplication.shared.run()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "pawprint.fill",
            accessibilityDescription: L10n.text("Codex Habitat overlay preview")
        )

        let menu = NSMenu()
        let interaction = NSMenuItem(
            title: L10n.text("Enable Click-Through"),
            action: #selector(toggleInteraction),
            keyEquivalent: ""
        )
        interaction.target = self
        menu.addItem(interaction)
        let widgets = NSMenuItem(
            title: L10n.text("Collapse Widgets"),
            action: #selector(toggleWidgets),
            keyEquivalent: ""
        )
        widgets.target = self
        menu.addItem(widgets)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L10n.text("Quit Preview"), action: #selector(quitPreview), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu

        statusItem = item
        interactionItem = interaction
        widgetItem = widgets
    }

    @objc private func toggleInteraction() {
        overlay.setInteractive(!overlay.isInteractive)
        interactionItem?.title = L10n.text(
            overlay.isInteractive ? "Enable Click-Through" : "Enable Interaction"
        )
    }

    @objc private func toggleWidgets() {
        presentation.isWidgetRailExpanded.toggle()
        widgetItem?.title = L10n.text(
            presentation.isWidgetRailExpanded ? "Collapse Widgets" : "Expand Widgets"
        )
    }

    @objc private func quitPreview() {
        NSApplication.shared.terminate(nil)
    }

    private static func loadPetAsset() -> OverlayPreviewPetAsset? {
        guard let entry = try? PetLibrary(root: PetLibrary.petRoot())
            .discover()
            .first(where: { $0.status == .valid }),
            let spritesheetURL = entry.spritesheetURL,
            let atlas = entry.atlas
        else {
            return nil
        }
        return OverlayPreviewPetAsset(
            renderer: SpriteSheetRenderer(contentsOf: spritesheetURL, atlas: atlas),
            availableRows: Set(0..<min(atlas.rows, 9))
        )
    }
}

@MainActor
private final class OverlayPreviewPresentation: ObservableObject {
    @Published var isWidgetRailExpanded = true
}

private struct OverlayPreviewPetAsset {
    let renderer: SpriteSheetRenderer
    let availableRows: Set<Int>
}

private struct OverlayPreviewView: View {
    @ObservedObject var presentation: OverlayPreviewPresentation
    @ObservedObject var widgetModel: WidgetRailModel
    @ObservedObject var petModel: HabitatOverlayModel
    let petAsset: OverlayPreviewPetAsset?
    let theme: HabitatThemeDescriptor

    var body: some View {
        ZStack(alignment: .topLeading) {
            if presentation.isWidgetRailExpanded {
                WidgetRailView(model: widgetModel, theme: theme)
                    .offset(x: 4, y: 4)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            petView
                .frame(
                    width: HabitatOverlayLayout.petSize.width,
                    height: HabitatOverlayLayout.petSize.height
                )
                .offset(x: 200)
        }
        .frame(
            width: HabitatOverlayLayout.containerSize.width,
            height: HabitatOverlayLayout.containerSize.height,
            alignment: .topLeading
        )
        .animation(.snappy(duration: 0.22), value: presentation.isWidgetRailExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("Codex Habitat overlay preview"))
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
            VStack(spacing: 10) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

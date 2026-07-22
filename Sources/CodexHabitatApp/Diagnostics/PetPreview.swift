import AppKit
import HabitatCore
import OverlayHost
import PetRuntime

@MainActor
enum PetPreview {
    private static var coordinator: PetPreviewCoordinator?

    static func run(id: String) async -> Int32 {
        let loaded = await Task.detached(priority: .userInitiated) {
            try? loadPet(id: id)
        }.value
        guard let loaded else {
            print("pet-preview: unavailable")
            return 1
        }
        let coordinator = PetPreviewCoordinator(
            renderer: loaded.renderer,
            availableRows: loaded.availableRows
        )
        self.coordinator = coordinator
        coordinator.run()
        return 0
    }

    nonisolated private static func loadPet(
        id: String
    ) throws -> (renderer: SpriteSheetRenderer, availableRows: Set<Int>)? {
        let entry = try PetLibrary(root: PetLibrary.petRoot())
            .discover()
            .first { $0.status == .valid && $0.manifest?.id == id }
        guard let entry,
              let spritesheetURL = entry.spritesheetURL,
              let atlas = entry.atlas
        else {
            return nil
        }
        let renderer = SpriteSheetRenderer(contentsOf: spritesheetURL, atlas: atlas)
        guard renderer.isRenderable else { return nil }
        return (renderer, Set(0..<min(atlas.rows, 9)))
    }
}

@MainActor
private final class PetPreviewCoordinator: NSObject {
    private let overlay = OverlayController(panelSize: HabitatOverlayLayout.collapsedSize)
    private let model: HabitatOverlayModel
    private let renderer: SpriteSheetRenderer
    private var statusItem: NSStatusItem?

    init(renderer: SpriteSheetRenderer, availableRows: Set<Int>) {
        self.renderer = renderer
        model = HabitatOverlayModel(
            initialSnapshot: HabitatSnapshot(activity: .working, connectionHealth: .online),
            availableRows: availableRows,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
    }

    func run() {
        NSApplication.shared.setActivationPolicy(.accessory)
        overlay.setContent(HabitatOverlayView(
            model: model,
            renderer: renderer,
            renderMode: .auto,
            pixelArtHint: true
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
            accessibilityDescription: L10n.text("Codex Habitat pet preview")
        )
        let menu = NSMenu()
        let quit = NSMenuItem(title: L10n.text("Quit Preview"), action: #selector(quitPreview), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc private func quitPreview() {
        NSApplication.shared.terminate(nil)
    }
}

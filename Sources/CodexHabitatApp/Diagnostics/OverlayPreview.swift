import AppKit
import OverlayHost
import SwiftUI

@MainActor
enum OverlayPreview {
    private static let coordinator = OverlayPreviewCoordinator()

    static func run() {
        coordinator.run()
    }
}

@MainActor
private final class OverlayPreviewCoordinator: NSObject {
    private let overlay = OverlayController(panelSize: CGSize(width: 160, height: 180))
    private var statusItem: NSStatusItem?
    private var interactionItem: NSMenuItem?

    func run() {
        NSApplication.shared.setActivationPolicy(.accessory)
        overlay.setContent(OverlayPlaceholderView())
        overlay.setInteractive(true)
        overlay.show()
        installStatusItem()
        NSApplication.shared.run()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "pawprint.fill",
            accessibilityDescription: "Codex Habitat overlay preview"
        )

        let menu = NSMenu()
        let interaction = NSMenuItem(
            title: "Enable Click-Through",
            action: #selector(toggleInteraction),
            keyEquivalent: ""
        )
        interaction.target = self
        menu.addItem(interaction)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Preview", action: #selector(quitPreview), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu

        statusItem = item
        interactionItem = interaction
    }

    @objc private func toggleInteraction() {
        overlay.setInteractive(!overlay.isInteractive)
        interactionItem?.title = overlay.isInteractive ? "Enable Click-Through" : "Enable Interaction"
    }

    @objc private func quitPreview() {
        NSApplication.shared.terminate(nil)
    }
}

private struct OverlayPlaceholderView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }

            VStack(spacing: 12) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(width: 160, height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Codex Habitat overlay preview")
    }
}

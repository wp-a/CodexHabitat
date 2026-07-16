import AppKit
import SwiftUI

@MainActor
final class HabitatSettingsWindowController: NSWindowController {
    convenience init() {
        self.init(window: nil)
    }

    func show(model: HabitatAppModel, activate: Bool = true) {
        if window == nil {
            let contentView = SettingsRootView(model: model)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Codex Habitat"
            window.minSize = CGSize(width: 760, height: 520)
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: contentView)
            window.center()
            self.window = window
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

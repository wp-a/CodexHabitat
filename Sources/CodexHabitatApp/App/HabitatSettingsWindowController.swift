import AppKit
import SwiftUI

@MainActor
final class HabitatSettingsWindowController: NSWindowController {
    convenience init() {
        self.init(window: nil)
    }

    func show(model: HabitatAppModel, activate: Bool = true) {
        let application = NSApplication.shared
        let desiredPolicy = Self.activationPolicy(for: application.activationPolicy())
        if desiredPolicy != application.activationPolicy() {
            application.setActivationPolicy(desiredPolicy)
        }
        if window == nil {
            let visualQAOptions = HabitatVisualQALaunchOptions.current
            let contentView = SettingsRootView(
                model: model,
                visualQAOptions: visualQAOptions
            )
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: visualQAOptions.settingsWidth,
                    height: 520
                ),
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
            application.activate(ignoringOtherApps: true)
        }
    }

    nonisolated static func activationPolicy(
        for current: NSApplication.ActivationPolicy
    ) -> NSApplication.ActivationPolicy {
        current == .prohibited ? .accessory : current
    }
}

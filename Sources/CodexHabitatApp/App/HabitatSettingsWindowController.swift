import AppKit
import SwiftUI

@MainActor
final class HabitatSettingsWindowController: NSWindowController {
    convenience init() {
        self.init(window: nil)
    }

    func show(
        model: HabitatAppModel,
        desktopController: HabitatDesktopController? = nil,
        activate: Bool = true,
        visualQAOptions: HabitatVisualQALaunchOptions = .current
    ) {
        let application = NSApplication.shared
        let desiredPolicy = Self.activationPolicy(for: application.activationPolicy())
        if desiredPolicy != application.activationPolicy() {
            application.setActivationPolicy(desiredPolicy)
        }
        if window == nil {
            let styleMask: NSWindow.StyleMask = [
                .titled, .closable, .miniaturizable, .resizable,
            ]
            let availableContentSize = NSScreen.main.map {
                NSWindow.contentRect(forFrameRect: $0.visibleFrame, styleMask: styleMask).size
            } ?? CGSize(width: 1_040, height: 680)
            let requestedWidth: CGFloat? = visualQAOptions == .disabled
                ? nil
                : CGFloat(visualQAOptions.settingsWidth)
            let initialContentSize = Self.initialContentSize(
                availableSize: availableContentSize,
                requestedWidth: requestedWidth
            )
            let contentView = SettingsRootView(
                model: model,
                desktopController: desktopController,
                visualQAOptions: visualQAOptions
            )
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: initialContentSize.width,
                    height: initialContentSize.height
                ),
                styleMask: styleMask,
                backing: .buffered,
                defer: false
            )
            window.title = "Codex Habitat"
            window.minSize = CGSize(width: 760, height: 520)
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: contentView)
            window.setContentSize(initialContentSize)
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
        .regular
    }

    nonisolated static func initialContentSize(
        availableSize: CGSize,
        requestedWidth: CGFloat? = nil
    ) -> CGSize {
        let minimum = CGSize(width: 760, height: 520)
        let target = CGSize(width: requestedWidth ?? 1_040, height: 680)
        return CGSize(
            width: min(target.width, max(availableSize.width, minimum.width)),
            height: min(target.height, max(availableSize.height, minimum.height))
        )
    }
}

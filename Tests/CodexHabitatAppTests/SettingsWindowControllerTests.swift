import AppKit
import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test
func prohibitedMenuBarPolicyPromotesToAnActivatableAccessory() {
    #expect(
        HabitatSettingsWindowController.activationPolicy(for: .prohibited) == .accessory
    )
    #expect(
        HabitatSettingsWindowController.activationPolicy(for: .regular) == .regular
    )
    #expect(
        HabitatSettingsWindowController.activationPolicy(for: .accessory) == .accessory
    )
}

@Test @MainActor
func reopeningTheRunningApplicationRequestsTheSettingsWindow() {
    var reopenCount = 0
    let delegate = HabitatApplicationDelegate {
        reopenCount += 1
    }

    let handled = delegate.applicationShouldHandleReopen(
        NSApplication.shared,
        hasVisibleWindows: false
    )

    #expect(handled)
    #expect(reopenCount == 1)
}

@Test @MainActor
func settingsNavigationUsesLocalSelectionState() {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatNavigationTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = HabitatAppModel(
        settingsStore: SettingsStore(root: root),
        petRoot: root.appending(path: "Pets")
    )
    model.selectedSettingsSection = .integrations
    var navigation = SettingsNavigationState(model: model)

    #expect(navigation.selectedSection == .integrations)
    navigation.selectedSection = .pets
    #expect(model.selectedSettingsSection == .integrations)
}

@Test @MainActor
func settingsWindowOpensAtAStableMinimumSizeAndIsReused() {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatWindowTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = HabitatAppModel(
        settingsStore: SettingsStore(root: root),
        petRoot: root.appending(path: "Pets")
    )
    let controller = HabitatSettingsWindowController()

    controller.show(model: model, activate: false)
    let originalWindow = controller.window

    #expect(originalWindow?.isVisible == true)
    #expect(originalWindow?.minSize == CGSize(width: 760, height: 520))
    controller.show(model: model, activate: false)
    #expect(controller.window === originalWindow)

    originalWindow?.close()
}

@Test @MainActor
func visualQASettingsWindowHonorsABoundedWideContentSize() {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatWideWindowTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = HabitatAppModel(
        settingsStore: SettingsStore(root: root),
        petRoot: root.appending(path: "Pets")
    )
    let options = HabitatVisualQALaunchOptions(arguments: [
        "CodexHabitatApp", "--visual-qa", "--visual-qa-settings-width", "1040",
    ])
    let controller = HabitatSettingsWindowController()

    controller.show(model: model, activate: false, visualQAOptions: options)

    #expect(controller.window?.contentLayoutRect.width == 1_040)
    controller.window?.close()
}

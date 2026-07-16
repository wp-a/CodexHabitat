import AppKit
import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

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

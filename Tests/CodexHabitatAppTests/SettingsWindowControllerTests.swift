import AppKit
import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test
func settingsWindowPromotesAccessoryToRegular() {
    #expect(
        HabitatSettingsWindowController.activationPolicy(for: .prohibited) == .regular
    )
    #expect(
        HabitatSettingsWindowController.activationPolicy(for: .regular) == .regular
    )
    #expect(
        HabitatSettingsWindowController.activationPolicy(for: .accessory) == .regular
    )
}

@Test
func loginItemAppleEventIsDetected() throws {
    let event = try #require(NSAppleEventDescriptor(
        eventClass: AEEventClass(kCoreEventClass),
        eventID: AEEventID(kAEOpenApplication),
        targetDescriptor: nil,
        returnID: AEReturnID(kAutoGenerateReturnID),
        transactionID: AETransactionID(kAnyTransactionID)
    ))
    event.setParam(
        NSAppleEventDescriptor(boolean: true),
        forKeyword: AEKeyword(keyAELaunchedAsLogInItem)
    )

    #expect(HabitatLaunchContext(event: event).launchedAsLoginItem)
    #expect(!HabitatLaunchContext(event: nil).launchedAsLoginItem)
}

@Test
func userLaunchOpensSettingsWhileLoginLaunchStaysQuiet() {
    #expect(HabitatLaunchPresentation.shouldShowSettings(
        launchedAsLoginItem: false,
        requiresOnboarding: false,
        arguments: ["CodexHabitatApp"]
    ))
    #expect(!HabitatLaunchPresentation.shouldShowSettings(
        launchedAsLoginItem: true,
        requiresOnboarding: false,
        arguments: ["CodexHabitatApp"]
    ))
    #expect(HabitatLaunchPresentation.shouldShowSettings(
        launchedAsLoginItem: true,
        requiresOnboarding: true,
        arguments: ["CodexHabitatApp"]
    ))
    #expect(HabitatLaunchPresentation.shouldShowSettings(
        launchedAsLoginItem: true,
        requiresOnboarding: false,
        arguments: ["CodexHabitatApp", "--show-settings"]
    ))
}

@Test
func mainBundleConfigurationDeclaresAStandardVisibleBuildThirteenApp() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(contentsOf: repositoryRoot.appending(path: "Config/Info.plist"))
    let plist = try #require(
        PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    )

    #expect(plist["LSUIElement"] == nil)
    #expect(plist["CFBundleVersion"] as? String == "13")
}

@Test
func releaseVerificationPinsTheExpectedMonotonicBuildNumber() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let verifier = try String(
        contentsOf: repositoryRoot.appending(path: "scripts/verify-release.sh"),
        encoding: .utf8
    )
    let builder = try String(
        contentsOf: repositoryRoot.appending(path: "scripts/build-app.sh"),
        encoding: .utf8
    )

    #expect(verifier.contains("HABITAT_EXPECTED_BUILD_NUMBER"))
    #expect(verifier.contains("bundle build does not match expected build"))
    #expect(builder.contains("Print :CFBundleVersion"))
    #expect(!builder.contains("BUILD_NUMBER=\"${BUILD_NUMBER:-11}\""))
    #expect(builder.contains("HABITAT_EXPECTED_BUILD_NUMBER=\"$BUILD_NUMBER\""))
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

@Test
func themeGalleryDoesNotRefreshTheEntireResourceLibraryOnAppearance() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift"
        ),
        encoding: .utf8
    )

    #expect(!source.contains(".onAppear(perform: model.refreshResources)"))
}

@Test
func themeGalleryCanSafelySubmitTheSelectedThemeToCodex() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift"
        ),
        encoding: .utf8
    )

    #expect(source.contains("confirmsCodexApply = true"))
    #expect(source.contains("await bridge.enable("))
    #expect(source.contains("model.setThemeBridgeEnabled(bridge.state == .active)"))
    let selectionStart = try #require(source.range(of: "private func selectTheme("))
    let selectionImplementation = source[selectionStart.lowerBound...]
    #expect(!selectionImplementation.contains("changesSelection"))
    #expect(!selectionImplementation.contains("bridge.canApply"))
    #expect(selectionImplementation.contains("model.codexBridgeThemeIDs.contains(themeID)"))
    #expect(source.contains(".disabled(!bridge.canApply)"))
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

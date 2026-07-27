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
func settingsWindowTargetsAComfortableSizeWithinTheDisplay() {
    #expect(
        HabitatSettingsWindowController.initialContentSize(
            availableSize: CGSize(width: 1_440, height: 900)
        ) == CGSize(width: 1_040, height: 680)
    )
    #expect(
        HabitatSettingsWindowController.initialContentSize(
            availableSize: CGSize(width: 900, height: 600)
        ) == CGSize(width: 900, height: 600)
    )
    #expect(
        HabitatSettingsWindowController.initialContentSize(
            availableSize: CGSize(width: 600, height: 400)
        ) == CGSize(width: 760, height: 520)
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

@Test @MainActor
func launchPresentsSettingsBeforeBridgeStatusCompletes() async {
    let recorder = LaunchSequenceRecorder()
    let gate = LaunchSequenceGate()

    let bridgeTask = HabitatLaunchSequence.start(
        shouldPresentSettings: true,
        presentSettings: {
            recorder.record("settings")
        },
        bridgeWork: {
            await gate.wait()
            recorder.record("bridge")
        }
    )

    #expect(recorder.events == ["settings"])
    await gate.resume()
    await bridgeTask.value
    #expect(recorder.events == ["settings", "bridge"])
}

@Test @MainActor
func quietLoginLaunchStillRunsBridgeWork() async {
    let recorder = LaunchSequenceRecorder()

    let bridgeTask = HabitatLaunchSequence.start(
        shouldPresentSettings: false,
        presentSettings: {
            recorder.record("settings")
        },
        bridgeWork: {
            recorder.record("bridge")
        }
    )

    await bridgeTask.value
    #expect(recorder.events == ["bridge"])
}

@Test
func testAndVisualQALaunchesNeverResumeALiveWatcher() {
    let normal = HabitatBridgeLaunchPolicy(
        arguments: ["CodexHabitatApp"],
        environment: [:]
    )
    let test = HabitatBridgeLaunchPolicy(
        arguments: ["CodexHabitatApp"],
        environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]
    )
    let visualQA = HabitatBridgeLaunchPolicy(
        arguments: ["CodexHabitatApp", "--visual-qa"],
        environment: [:]
    )

    #expect(normal.allowsStatusRefresh)
    #expect(normal.allowsWatcherResume)
    #expect(!test.allowsStatusRefresh)
    #expect(!test.allowsWatcherResume)
    #expect(visualQA.allowsStatusRefresh)
    #expect(!visualQA.allowsWatcherResume)
}

@Test
func testAndVisualQAExitsNeverRestoreCodexAppearance() {
    let normal = HabitatBridgeTerminationPolicy(
        arguments: ["CodexHabitatApp"],
        environment: [:]
    )
    let test = HabitatBridgeTerminationPolicy(
        arguments: ["CodexHabitatApp"],
        environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]
    )
    let visualQA = HabitatBridgeTerminationPolicy(
        arguments: ["CodexHabitatApp", "--visual-qa"],
        environment: [:]
    )

    #expect(normal.allowsAppearanceRestore)
    #expect(normal.allowsPersistentBridgeStateMutation)
    #expect(!test.allowsAppearanceRestore)
    #expect(!test.allowsPersistentBridgeStateMutation)
    #expect(!visualQA.allowsAppearanceRestore)
    #expect(!visualQA.allowsPersistentBridgeStateMutation)
}

@Test
func mainBundleConfigurationDeclaresAStandardVisibleBuildSixteenApp() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(contentsOf: repositoryRoot.appending(path: "Config/Info.plist"))
    let plist = try #require(
        PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    )

    #expect(plist["LSUIElement"] == nil)
    #expect(plist["CFBundleVersion"] as? String == "16")
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
    let releaseWorkflow = try String(
        contentsOf: repositoryRoot.appending(path: ".github/workflows/release.yml"),
        encoding: .utf8
    )

    #expect(verifier.contains("HABITAT_EXPECTED_BUILD_NUMBER"))
    #expect(verifier.contains("HABITAT_EXPECTED_BUILD_NUMBER:-${BUILD_NUMBER:-"))
    #expect(verifier.contains("bundle build does not match expected build"))
    #expect(builder.contains("Print :CFBundleVersion"))
    #expect(!builder.contains("BUILD_NUMBER=\"${BUILD_NUMBER:-11}\""))
    #expect(builder.contains("HABITAT_EXPECTED_BUILD_NUMBER=\"$BUILD_NUMBER\""))
    #expect(releaseWorkflow.contains(
        "HABITAT_EXPECTED_BUILD_NUMBER: ${{ github.run_number }}"
    ))
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
func settingsRootConstructsPetsWithTheSharedDesktopController() {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatPetSettingsWiringTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = HabitatAppModel(
        settingsStore: SettingsStore(root: root),
        petRoot: root.appending(path: "Pets")
    )
    let desktopController = HabitatDesktopController()
    let settingsRoot = SettingsRootView(
        model: model,
        desktopController: desktopController
    )

    let pets = settingsRoot.makePetsSettingsView()

    #expect(pets.desktopController === desktopController)
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

    #expect(source.contains("requestInspectorApply"))
    #expect(source.contains("await bridge.enable("))
    #expect(source.contains("model.setThemeBridgeActive(true, themeID: themeID)"))
    let selectionStart = try #require(source.range(of: "private func selectTheme("))
    let selectionEnd = try #require(source.range(
        of: "private func requestInspectorApply",
        range: selectionStart.upperBound..<source.endIndex
    ))
    let selectionImplementation = source[selectionStart.lowerBound..<selectionEnd.lowerBound]
    #expect(!selectionImplementation.contains("confirmsCodexApply"))
    #expect(!selectionImplementation.contains("bridge."))
    #expect(selectionImplementation.contains("recordRecentlyPreviewedTheme"))
    #expect(source.contains(".disabled(!bridge.canApply)"))

    let habitatSelectionStart = try #require(source.range(
        of: "private func useSelectedThemeInHabitat"
    ))
    let habitatSelectionEnd = try #require(source.range(
        of: "private func requestInspectorApply",
        range: habitatSelectionStart.upperBound..<source.endIndex
    ))
    let habitatSelection = source[
        habitatSelectionStart.lowerBound..<habitatSelectionEnd.lowerBound
    ]
    #expect(habitatSelection.contains("model.selectTheme(selectedTheme.id)"))
    #expect(!habitatSelection.contains("bridge."))
    #expect(source.contains("themes.use-in-habitat"))
    #expect(source.contains("themes.apply-to-codex"))
}

@Test
func bridgeResumeUsesThePersistedCodexThemeInsteadOfTheHabitatSelection() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(path: "Sources/CodexHabitatApp/CodexHabitatApp.swift"),
        encoding: .utf8
    )
    let resumeStart = try #require(source.range(of: "await bridge.resumeWatching("))
    let resumeEnd = try #require(source.range(
        of: ")",
        range: resumeStart.upperBound..<source.endIndex
    ))
    let resumeCall = source[resumeStart.lowerBound...resumeEnd.lowerBound]

    #expect(resumeCall.contains("themeID: bridgeThemeID"))
    #expect(!resumeCall.contains("model.settings.selectedThemeID"))
}

@Test
func compactOverviewAndScaleControlsKeepNativeInteractionContracts() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let habitatSource = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/HabitatSettingsView.swift"
        ),
        encoding: .utf8
    )
    let petsSource = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/PetsSettingsView.swift"
        ),
        encoding: .utf8
    )

    #expect(habitatSource.contains("ViewThatFits(in: .horizontal)"))
    #expect(habitatSource.contains(".accessibilityLabel(L10n.text(\"Scale\"))"))
    #expect(habitatSource.contains(".accessibilityValue(scaleAccessibilityValue)"))
    #expect(petsSource.contains(".accessibilityLabel(L10n.text(\"Scale\"))"))
    #expect(petsSource.contains(".accessibilityValue(scaleAccessibilityValue)"))
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

    let contentWidth = controller.window?.contentLayoutRect.width ?? 0
    #expect(contentWidth >= 760)
    #expect(contentWidth <= 1_040)
    controller.window?.close()
}

@MainActor
private final class LaunchSequenceRecorder {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private actor LaunchSequenceGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

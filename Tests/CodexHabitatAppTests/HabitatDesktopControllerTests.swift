import Foundation
import CoreGraphics
import HabitatCore
import PetRuntime
import Testing
@testable import CodexHabitatApp

@Test @MainActor
func completedSetupShowsAndHidesTheDesktopHabitat() {
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true

    controller.apply(settings: settings, pets: [], isVisible: true)

    #expect(controller.isVisible)
    #expect(controller.isPetAnimationActive)
    #expect(controller.panelSize == HabitatOverlayLayout.expandedSize)
    #expect(controller.isInteractive)

    settings.clickThrough = true
    controller.apply(settings: settings, pets: [], isVisible: true)
    #expect(controller.isInteractive == false)

    controller.apply(settings: settings, pets: [], isVisible: false)
    #expect(controller.isVisible == false)
    #expect(!controller.isPetAnimationActive)
}

@Test @MainActor
func collapsingAndExpandingResizeImmediatelyAndKeepThePetRightAnchored() {
    let controller = HabitatDesktopController(expansionAnimationDuration: 0)
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    controller.apply(settings: settings, pets: [], isVisible: true)
    let rightEdge = controller.panelFrame.maxX
    controller.beginTemporaryMoveMode()

    controller.setWidgetRailExpanded(false)

    #expect(controller.panelSize == HabitatOverlayLayout.collapsedSize)
    #expect(controller.panelFrame.maxX == rightEdge)
    #expect(controller.isTemporaryMoveMode)
    #expect(controller.dragRegionFrame == CGRect(
        origin: .zero,
        size: HabitatOverlayLayout.petSize
    ))

    controller.setWidgetRailExpanded(true)

    #expect(controller.panelSize == HabitatOverlayLayout.expandedSize)
    #expect(controller.panelFrame.maxX == rightEdge)
    #expect(controller.isTemporaryMoveMode)
    #expect(controller.dragRegionFrame == CGRect(
        origin: CGPoint(x: 188, y: 0),
        size: HabitatOverlayLayout.petSize
    ))
}

@Test @MainActor
func rapidExpansionChangesCannotReplayAStaleResize() async throws {
    let controller = HabitatDesktopController(
        expansionAnimationDuration: 0.05,
        expansionFrameInterval: 0.005
    )
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    controller.apply(settings: settings, pets: [], isVisible: true)
    let rightEdge = controller.panelFrame.maxX

    controller.setWidgetRailExpanded(false)
    await Task.yield()
    controller.setWidgetRailExpanded(true)
    await Task.yield()
    controller.setWidgetRailExpanded(false)

    for _ in 0..<100 {
        #expect(controller.panelFrame.maxX == rightEdge)
        #expect(controller.contentSize == controller.panelSize)
        #expect(controller.dragRegionFrame.maxX == controller.panelSize.width)
        if controller.panelSize == HabitatOverlayLayout.collapsedSize {
            break
        }
        await Task.yield()
    }

    try await Task.sleep(for: .milliseconds(80))

    #expect(controller.panelSize == HabitatOverlayLayout.collapsedSize)
    #expect(controller.panelFrame.maxX == rightEdge)
    #expect(controller.dragRegionFrame == CGRect(origin: .zero, size: HabitatOverlayLayout.petSize))
}

@Test @MainActor
func visualQAInitializerCanStartWithThePhysicalPanelCollapsed() {
    let controller = HabitatDesktopController(isWidgetRailExpanded: false)
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true

    controller.apply(settings: settings, pets: [], isVisible: true)

    #expect(controller.panelSize == HabitatOverlayLayout.collapsedSize)
}

@Test @MainActor
func incompleteSetupNeverShowsTheDesktopHabitat() {
    let controller = HabitatDesktopController()

    controller.apply(settings: .default, pets: [], isVisible: true)

    #expect(controller.isVisible == false)
}

@Test @MainActor
func changingReduceMotionRebuildsTheActivePetDriverImmediately() {
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.reduceMotion = .full
    controller.apply(settings: settings, pets: [], isVisible: true)
    #expect(controller.currentPetReduceMotion == false)

    settings.reduceMotion = .reduce
    controller.apply(settings: settings, pets: [], isVisible: true)

    #expect(controller.currentPetReduceMotion == true)
}

@Test @MainActor
func liveSnapshotUpdatesDesktopPetAndWidgets() {
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    controller.apply(settings: settings, pets: [], isVisible: true)
    let snapshot = HabitatSnapshot(
        activity: .attention,
        threadIDHash: "local-hash",
        eventTimestamp: Date(timeIntervalSince1970: 250),
        connectionHealth: .online,
        primaryRateLimit: RateLimitSummary(usedPercent: 31, resetAt: nil)
    )

    controller.apply(snapshot: snapshot)

    #expect(controller.currentSnapshot == snapshot)
    #expect(controller.currentPetSnapshot == snapshot)
    #expect(controller.currentWidgetSnapshot == snapshot)
}

@Test @MainActor
func desktopUsesASelectedInstalledThemeDescriptor() {
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedThemeID = "studio.example.theme"
    let theme = HabitatThemeDescriptor(
        id: "studio.example.theme",
        name: "Installed Theme",
        detail: "Fixture",
        symbol: "shippingbox.fill",
        surfaceHex: "#101010",
        textHex: "#F0F0F0",
        accentHex: "#00A0A0",
        attentionHex: "#F0A000",
        errorHex: "#E04040",
        previewURL: nil
    )

    controller.apply(settings: settings, pets: [], isVisible: true, themes: [theme])

    #expect(controller.currentThemeID == theme.id)
}

@Test @MainActor
func changingOnlyTheThemeReusesTheLoadedPetRenderer() async throws {
    let testsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let petRoot = testsRoot.appending(path: "PetRuntimeTests/Fixtures", directoryHint: .isDirectory)
    let pet = try #require(
        PetLibrary(root: petRoot).discover().first(where: { $0.manifest?.id == "test-pet" })
    )
    let recorder = RendererThreadRecorder()
    let controller = HabitatDesktopController { url, atlas in
        recorder.recordLoad(onMainThread: Thread.isMainThread)
        return SpriteSheetRenderer(contentsOf: url, atlas: atlas)
    }
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedPetID = "test-pet"

    controller.apply(settings: settings, pets: [pet], isVisible: true)
    await waitForPetRenderMode(.auto, in: controller)
    #expect(recorder.mainThreadLoads.count == 1)

    settings.selectedThemeID = "night-shift"
    controller.apply(settings: settings, pets: [pet], isVisible: true)

    #expect(recorder.mainThreadLoads.count == 1)
}

@Test @MainActor
func switchingPetsBuildsTheNewRendererAwayFromTheMainActor() async {
    let recorder = RendererThreadRecorder()
    let controller = HabitatDesktopController { _, atlas in
        recorder.recordLoad(onMainThread: Thread.isMainThread)
        return SpriteSheetRenderer(image: desktopRenderableTestImage(), atlas: atlas)
    }
    let firstPet = desktopTestPet(id: "first-pet")
    let secondPet = desktopTestPet(id: "second-pet")
    let presentations = [
        "first-pet": HabitatPetPresentation(renderMode: .smooth, scale: 1),
        "second-pet": HabitatPetPresentation(renderMode: .pixelated, scale: 1),
    ]
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedPetID = "first-pet"

    controller.apply(
        settings: settings,
        pets: [firstPet, secondPet],
        petPresentations: presentations,
        isVisible: true
    )
    await waitForPetRenderMode(.smooth, in: controller)

    settings.selectedPetID = "second-pet"
    controller.apply(
        settings: settings,
        pets: [firstPet, secondPet],
        petPresentations: presentations,
        isVisible: true
    )
    await waitForPetRenderMode(.pixelated, in: controller)

    #expect(recorder.mainThreadLoads.count == 2)
    #expect(recorder.mainThreadLoads[1] == false)
}

@Test @MainActor
func failedPetDecodeKeepsThePreviousRendererAndReportsTheRequestedSelection() async throws {
    let validImage = try desktopTestImage()
    let controller = HabitatDesktopController { url, atlas in
        SpriteSheetRenderer(
            image: url.deletingLastPathComponent().lastPathComponent == "first-pet"
                ? validImage
                : nil,
            atlas: atlas
        )
    }
    let firstPet = desktopTestPet(id: "first-pet")
    let secondPet = desktopTestPet(id: "second-pet")
    let presentations = [
        "first-pet": HabitatPetPresentation(renderMode: .smooth, scale: 1),
        "second-pet": HabitatPetPresentation(renderMode: .pixelated, scale: 1),
    ]
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedPetID = "first-pet"
    controller.apply(
        settings: settings,
        pets: [firstPet, secondPet],
        petPresentations: presentations,
        isVisible: true
    )
    await waitForPetRenderMode(.smooth, in: controller)

    settings.selectedPetID = "second-pet"
    controller.apply(
        settings: settings,
        pets: [firstPet, secondPet],
        petPresentations: presentations,
        isVisible: true
    )
    await waitForPetLoadFailure(in: controller)

    #expect(controller.currentSelectedPetID == "second-pet")
    #expect(controller.currentPetRenderMode == .smooth)
    #expect(controller.petLoadError != nil)
}

@Test @MainActor
func failedPetDecodeCanBeRetriedWithoutDroppingThePreviousRenderer() async throws {
    let validImage = try desktopTestImage()
    let attempts = PetDecodeAttemptCounter()
    let controller = HabitatDesktopController { url, atlas in
        let petID = url.deletingLastPathComponent().lastPathComponent
        let attempt = attempts.record(petID)
        return SpriteSheetRenderer(
            image: petID == "first-pet" || attempt > 1 ? validImage : nil,
            atlas: atlas
        )
    }
    let firstPet = desktopTestPet(id: "first-pet")
    let secondPet = desktopTestPet(id: "second-pet")
    let presentations = [
        "first-pet": HabitatPetPresentation(renderMode: .smooth, scale: 1),
        "second-pet": HabitatPetPresentation(renderMode: .pixelated, scale: 1),
    ]
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedPetID = "first-pet"
    controller.apply(settings: settings, pets: [firstPet, secondPet], petPresentations: presentations, isVisible: true)
    await waitForPetRenderMode(.smooth, in: controller)

    settings.selectedPetID = "second-pet"
    controller.apply(settings: settings, pets: [firstPet, secondPet], petPresentations: presentations, isVisible: true)
    await waitForPetLoadFailure(in: controller)
    controller.retryPetRendererLoad()
    await waitForPetRenderMode(.pixelated, in: controller)

    #expect(controller.petLoadError == nil)
    #expect(attempts.count(for: "second-pet") == 2)
}

@Test @MainActor
func switchingBackBeforeAQueuedRendererFinishesDiscardsTheStaleSelection() async {
    let gate = RendererLoadGate(blockedPetID: "second-pet")
    let controller = HabitatDesktopController { url, atlas in
        gate.load(url: url, atlas: atlas)
    }
    let firstPet = desktopTestPet(id: "first-pet")
    let secondPet = desktopTestPet(id: "second-pet")
    let presentations = [
        "first-pet": HabitatPetPresentation(renderMode: .smooth, scale: 1),
        "second-pet": HabitatPetPresentation(renderMode: .pixelated, scale: 1),
    ]
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedPetID = "first-pet"
    controller.apply(
        settings: settings,
        pets: [firstPet, secondPet],
        petPresentations: presentations,
        isVisible: true
    )
    await waitForPetRenderMode(.smooth, in: controller)

    settings.selectedPetID = "second-pet"
    controller.apply(
        settings: settings,
        pets: [firstPet, secondPet],
        petPresentations: presentations,
        isVisible: true
    )
    await waitForRendererLoad(of: "second-pet", in: gate)

    settings.selectedPetID = "first-pet"
    controller.apply(
        settings: settings,
        pets: [firstPet, secondPet],
        petPresentations: presentations,
        isVisible: true
    )
    gate.releaseBlockedLoad()
    await waitForRendererLoadCompletion(of: "second-pet", in: gate)
    for _ in 0..<100 {
        await Task.yield()
    }

    #expect(controller.currentPetRenderMode == .smooth)
    #expect(gate.loadedPetIDs == ["first-pet", "second-pet"])
}

@Test @MainActor
func switchingAgainWhileARendererIsBlockedSerializesTheNextLoad() async {
    let gate = RendererLoadGate(blockedPetID: "second-pet")
    let controller = HabitatDesktopController { url, atlas in
        gate.load(url: url, atlas: atlas)
    }
    let firstPet = desktopTestPet(id: "first-pet")
    let secondPet = desktopTestPet(id: "second-pet")
    let thirdPet = desktopTestPet(id: "third-pet")
    let pets = [firstPet, secondPet, thirdPet]
    let presentations = [
        "first-pet": HabitatPetPresentation(renderMode: .smooth, scale: 1),
        "second-pet": HabitatPetPresentation(renderMode: .pixelated, scale: 1),
        "third-pet": HabitatPetPresentation(renderMode: .auto, scale: 1),
    ]
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedPetID = "first-pet"
    controller.apply(
        settings: settings,
        pets: pets,
        petPresentations: presentations,
        isVisible: true
    )
    await waitForPetRenderMode(.smooth, in: controller)

    settings.selectedPetID = "second-pet"
    controller.apply(
        settings: settings,
        pets: pets,
        petPresentations: presentations,
        isVisible: true
    )
    await waitForRendererLoad(of: "second-pet", in: gate)

    settings.selectedPetID = "third-pet"
    controller.apply(
        settings: settings,
        pets: pets,
        petPresentations: presentations,
        isVisible: true
    )
    await allowPendingRendererLoadsToStart()

    #expect(!gate.hasStarted("third-pet"))
    gate.releaseBlockedLoad()
    await waitForRendererLoadCompletion(of: "second-pet", in: gate)
    await waitForPetRenderMode(.auto, in: controller)

    #expect(gate.loadedPetIDs == ["first-pet", "second-pet", "third-pet"])
}

@Test @MainActor
func desktopConsumesResourcePetRenderingAndScale() async throws {
    let testsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let petRoot = testsRoot.appending(path: "PetRuntimeTests/Fixtures", directoryHint: .isDirectory)
    let pet = try #require(
        PetLibrary(root: petRoot).discover().first(where: { $0.manifest?.id == "test-pet" })
    )
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.selectedPetID = "test-pet"

    controller.apply(
        settings: settings,
        pets: [pet],
        petPresentations: [
            "test-pet": HabitatPetPresentation(renderMode: .smooth, scale: 1.5),
        ],
        isVisible: true
    )
    await waitForPetRenderMode(.smooth, in: controller)

    #expect(controller.currentPetRenderMode == .smooth)
    #expect(controller.currentPetScale == 1.5)
}

@Test @MainActor
func temporaryMoveModeOverridesClickThroughAndLockWithoutChangingSettings() {
    let controller = HabitatDesktopController()
    var settings = HabitatSettings.default
    settings.onboardingCompleted = true
    settings.clickThrough = true
    settings.positionLocked = true
    controller.apply(settings: settings, pets: [], isVisible: true)

    #expect(!controller.isInteractive)
    #expect(!controller.isMovementEnabled)

    controller.beginTemporaryMoveMode()

    #expect(controller.isTemporaryMoveMode)
    #expect(controller.isInteractive)
    #expect(controller.isMovementEnabled)
    #expect(settings.clickThrough)
    #expect(settings.positionLocked)

    controller.endTemporaryMoveMode()

    #expect(!controller.isTemporaryMoveMode)
    #expect(!controller.isInteractive)
    #expect(!controller.isMovementEnabled)
}

@MainActor
private func waitForPetRenderMode(
    _ expectedMode: PetRenderMode,
    in controller: HabitatDesktopController
) async {
    for _ in 0..<1_000 where controller.currentPetRenderMode != expectedMode {
        await Task.yield()
    }
}

@MainActor
private func waitForPetLoadFailure(in controller: HabitatDesktopController) async {
    for _ in 0..<1_000 where controller.petLoadError == nil {
        await Task.yield()
    }
}

private final class RendererThreadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedMainThreadLoads: [Bool] = []

    var mainThreadLoads: [Bool] {
        lock.withLock { recordedMainThreadLoads }
    }

    func recordLoad(onMainThread: Bool) {
        lock.withLock { recordedMainThreadLoads.append(onMainThread) }
    }
}

private final class PetDecodeAttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]

    func record(_ petID: String) -> Int {
        lock.withLock {
            counts[petID, default: 0] += 1
            return counts[petID, default: 0]
        }
    }

    func count(for petID: String) -> Int {
        lock.withLock { counts[petID, default: 0] }
    }
}

private final class RendererLoadGate: @unchecked Sendable {
    private let lock = NSLock()
    private let blockedPetID: String
    private let blockedLoad = DispatchSemaphore(value: 0)
    private var recordedPetIDs: [String] = []
    private var completedPetIDs: Set<String> = []
    private var startedWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var completedWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    init(blockedPetID: String) {
        self.blockedPetID = blockedPetID
    }

    var loadedPetIDs: [String] {
        lock.withLock { recordedPetIDs }
    }

    func hasStarted(_ petID: String) -> Bool {
        lock.withLock { recordedPetIDs.contains(petID) }
    }

    func hasCompleted(_ petID: String) -> Bool {
        lock.withLock { completedPetIDs.contains(petID) }
    }

    func load(url: URL, atlas: PetAtlasMetadata) -> SpriteSheetRenderer {
        let petID = url.deletingLastPathComponent().lastPathComponent
        let startContinuations = lock.withLock {
            recordedPetIDs.append(petID)
            return startedWaiters.removeValue(forKey: petID) ?? []
        }
        startContinuations.forEach { $0.resume() }
        if petID == blockedPetID {
            blockedLoad.wait()
        }
        let completionContinuations = lock.withLock {
            _ = completedPetIDs.insert(petID)
            return completedWaiters.removeValue(forKey: petID) ?? []
        }
        completionContinuations.forEach { $0.resume() }
        return SpriteSheetRenderer(image: desktopRenderableTestImage(), atlas: atlas)
    }

    func releaseBlockedLoad() {
        blockedLoad.signal()
    }

    func waitUntilStarted(_ petID: String) async {
        await withCheckedContinuation { continuation in
            let alreadyStarted = lock.withLock {
                if recordedPetIDs.contains(petID) {
                    return true
                }
                startedWaiters[petID, default: []].append(continuation)
                return false
            }
            if alreadyStarted {
                continuation.resume()
            }
        }
    }

    func waitUntilCompleted(_ petID: String) async {
        await withCheckedContinuation { continuation in
            let alreadyCompleted = lock.withLock {
                if completedPetIDs.contains(petID) {
                    return true
                }
                completedWaiters[petID, default: []].append(continuation)
                return false
            }
            if alreadyCompleted {
                continuation.resume()
            }
        }
    }
}

private func waitForRendererLoad(
    of petID: String,
    in gate: RendererLoadGate
) async {
    await gate.waitUntilStarted(petID)
}

private func waitForRendererLoadCompletion(
    of petID: String,
    in gate: RendererLoadGate
) async {
    await gate.waitUntilCompleted(petID)
}

private func allowPendingRendererLoadsToStart() async {
    for _ in 0..<1_000 {
        await Task.yield()
    }
}

private func desktopTestPet(id: String) -> PetLibraryEntry {
    let root = URL(fileURLWithPath: "/tmp/\(id)", isDirectory: true)
    return PetLibraryEntry(
        packageURL: root,
        manifest: PetManifest(
            id: id,
            displayName: id,
            description: "Test fixture",
            spritesheetPath: "spritesheet.png"
        ),
        spritesheetURL: root.appending(path: "spritesheet.png"),
        atlas: PetAtlasMetadata(pixelWidth: 8, pixelHeight: 9, columns: 8, rows: 9),
        status: .valid
    )
}

private func desktopTestImage() throws -> CGImage {
    let context = try #require(CGContext(
        data: nil,
        width: 8,
        height: 9,
        bitsPerComponent: 8,
        bytesPerRow: 32,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    return try #require(context.makeImage())
}

private func desktopRenderableTestImage() -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: 8,
        height: 9,
        bitsPerComponent: 8,
        bytesPerRow: 32,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let image = context.makeImage()
    else {
        fatalError("Could not build the renderer test image")
    }
    return image
}

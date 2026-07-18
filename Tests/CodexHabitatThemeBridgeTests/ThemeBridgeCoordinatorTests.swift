import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func successfulApplyRestartsOnceChecksLayoutAndWritesPrivateScreenshot() async throws {
    let fixture = try CoordinatorFixture()
    defer { fixture.cleanup() }
    let screenshotURL = fixture.root.appending(path: "theme.png")

    let result = try await fixture.coordinator.apply(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
        authorized: true,
        screenshotURL: screenshotURL
    )

    #expect(result.targetCount == 1)
    #expect(result.healthReport.passed)
    #expect(fixture.restarter.prepareCount == 1)
    #expect(fixture.restarter.normalLaunches.isEmpty)
    #expect(fixture.session.startCount == 1)
    #expect(fixture.client.installedTargets == [fixture.target])
    #expect(fixture.client.installedHomeMarkers == ["[data-testid=\"home-icon\"]"])
    let expectedProfile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: fixture.bundle.version)
    )
    #expect(
        fixture.client.installedAnnotationPlans
            == [HostSurfaceAnnotationPlan(profile: expectedProfile)]
    )
    #expect(try Data(contentsOf: screenshotURL) == fixture.client.screenshot)
    let attributes = try FileManager.default.attributesOfItem(atPath: screenshotURL.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@Test
func unhealthyLayoutFailsClosedRemovesStyleStopsSessionAndLaunchesNormally() async throws {
    let fixture = try CoordinatorFixture(healthy: false)
    defer { fixture.cleanup() }

    await #expect(throws: ThemeBridgeCoordinatorError.healthCheckFailed) {
        _ = try await fixture.coordinator.apply(
            bundleURL: fixture.bundle.bundleURL,
            theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
            authorized: true,
            screenshotURL: nil
        )
    }

    #expect(fixture.client.installedTargets.isEmpty)
    #expect(fixture.client.removedTargets.isEmpty)
    #expect(fixture.session.stopCount == 1)
    #expect(fixture.restarter.normalLaunches == [fixture.bundle.bundleURL])
}

@Test
func postInstallHealthFailureCleansBootstrapAndAllowsANewSession() async throws {
    let fixture = try CoordinatorFixture(postInstallHealthy: false)
    defer { fixture.cleanup() }

    await #expect(throws: ThemeBridgeCoordinatorError.healthCheckFailed) {
        _ = try await fixture.coordinator.apply(
            bundleURL: fixture.bundle.bundleURL,
            theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
            authorized: true,
            screenshotURL: nil
        )
    }

    #expect(fixture.client.installedTargets == [fixture.target])
    #expect(fixture.client.removedTargets == [fixture.target])
    #expect(fixture.session.stopCount == 1)
    #expect(fixture.restarter.normalLaunches == [fixture.bundle.bundleURL])

    fixture.session.currentStatus = .active(fixture.record)
    let installed = try await fixture.coordinator.maintain(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil)
    )
    #expect(installed == 1)
}

@Test
func auxiliaryRendererFailingNativeLayoutIsNeverStyled() async throws {
    let fixture = try CoordinatorFixture()
    defer { fixture.cleanup() }
    let auxiliary = CDPTarget(
        id: "auxiliary-page",
        type: "page",
        title: "Auxiliary",
        url: URL(
            string: "app://codex/index.html?initialRoute=%2Ffuture-auxiliary"
        )!,
        webSocketDebuggerURL: URL(
            string: "ws://127.0.0.1:55000/devtools/page/auxiliary-page"
        )!
    )
    fixture.client.targets = [auxiliary, fixture.target]
    fixture.client.snapshotsByTargetID[auxiliary.id] = LayoutHealthSnapshot(
        appShellVisible: false,
        sidebarVisible: false,
        mainSurfaceVisible: false,
        headerVisible: false,
        composerVisible: false,
        composerAcceptsPointerEvents: false,
        composerHitTestable: false,
        threadCanScroll: false,
        requiredSurfaceAnnotationsPresent: false,
        popoversWithinViewport: true,
        controlsWithinViewport: false,
        horizontalOverflowPixels: 0
    )

    let result = try await fixture.coordinator.apply(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
        authorized: true,
        screenshotURL: nil
    )

    #expect(result.targetCount == 1)
    #expect(fixture.client.installedTargets == [fixture.target])
    #expect(fixture.client.removedTargets.isEmpty)
}

@Test
func unknownVersionAndUnownedListenerFailClosedBeforeInjection() async throws {
    let unknown = try CoordinatorFixture(version: "26.708.0")
    defer { unknown.cleanup() }
    await #expect(throws: ThemeBridgeCoordinatorError.unsupportedCodexVersion("26.708.0")) {
        _ = try await unknown.coordinator.apply(
            bundleURL: unknown.bundle.bundleURL,
            theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
            authorized: true,
            screenshotURL: nil
        )
    }
    #expect(unknown.client.installedTargets.isEmpty)
    #expect(unknown.restarter.prepareCount == 0)
    #expect(unknown.session.startCount == 0)
    #expect(unknown.session.stopCount == 0)
    #expect(unknown.restarter.normalLaunches.isEmpty)

    let unowned = try CoordinatorFixture(listenerOwned: false)
    defer { unowned.cleanup() }
    await #expect(throws: ThemeBridgeCoordinatorError.listenerNotOwned) {
        _ = try await unowned.coordinator.apply(
            bundleURL: unowned.bundle.bundleURL,
            theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
            authorized: true,
            screenshotURL: nil
        )
    }
    #expect(unowned.client.installedTargets.isEmpty)
    #expect(unowned.session.stopCount == 1)
    #expect(unowned.restarter.normalLaunches == [unowned.bundle.bundleURL])
}

@Test
func staticallyVerifiedCurrentVersionAppliesThroughTheHealthGate() async throws {
    let fixture = try CoordinatorFixture(version: "26.715.31251")
    defer { fixture.cleanup() }

    let result = try await fixture.coordinator.apply(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
        authorized: true,
        screenshotURL: nil
    )

    #expect(result.healthReport.passed)
    #expect(fixture.restarter.prepareCount == 1)
    #expect(fixture.client.installedTargets == [fixture.target])
    #expect(fixture.restarter.normalLaunches.isEmpty)
}

@Test
func restoreRemovesInjectedStyleStopsExactSessionAndLaunchesOfficialApp() async throws {
    let fixture = try CoordinatorFixture(initiallyActive: true)
    defer { fixture.cleanup() }

    try await fixture.coordinator.restore(bundleURL: fixture.bundle.bundleURL)

    #expect(fixture.client.removedTargets == [fixture.target])
    #expect(fixture.session.stopCount == 1)
    #expect(fixture.restarter.normalLaunches == [fixture.bundle.bundleURL])
}

@Test
func restoreUsesInstallingClientAndClearsMaintenanceState() async throws {
    let fixture = try CoordinatorFixture(
        initiallyActive: true,
        usesFreshClientAfterFirstRequest: true
    )
    defer { fixture.cleanup() }

    _ = try await fixture.coordinator.apply(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
        authorized: true,
        screenshotURL: nil
    )
    try await fixture.coordinator.restore(bundleURL: fixture.bundle.bundleURL)

    #expect(fixture.client.removedTargets == [fixture.target])
    #expect(fixture.freshClient.removedTargets.isEmpty)

    fixture.session.currentStatus = .active(fixture.record)
    let installed = try await fixture.coordinator.maintain(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil)
    )
    #expect(installed == 1)
}

@Test
func repeatedApplyReusesTheClientThatOwnsTheBootstrap() async throws {
    let fixture = try CoordinatorFixture(
        initiallyActive: true,
        usesFreshClientAfterFirstRequest: true
    )
    defer { fixture.cleanup() }

    for _ in 0..<2 {
        _ = try await fixture.coordinator.apply(
            bundleURL: fixture.bundle.bundleURL,
            theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
            authorized: true,
            screenshotURL: nil
        )
    }

    #expect(fixture.client.installedTargets == [fixture.target, fixture.target])
    #expect(fixture.freshClient.installedTargets.isEmpty)
}

@Test
func failedRemovalAndStopRetainTheInstallingClientForRestoreRetry() async throws {
    let fixture = try CoordinatorFixture(
        initiallyActive: true,
        usesFreshClientAfterFirstRequest: true
    )
    defer { fixture.cleanup() }
    _ = try await fixture.coordinator.apply(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
        authorized: true,
        screenshotURL: nil
    )
    fixture.client.removeFails = true
    fixture.session.stopFails = true

    await #expect(throws: StubCoordinatorFailure.self) {
        try await fixture.coordinator.restore(bundleURL: fixture.bundle.bundleURL)
    }

    fixture.client.removeFails = false
    fixture.session.stopFails = false
    try await fixture.coordinator.restore(bundleURL: fixture.bundle.bundleURL)

    #expect(fixture.client.removeAttempts == [fixture.target, fixture.target])
    #expect(fixture.client.removedTargets == [fixture.target])
    #expect(fixture.freshClient.removedTargets.isEmpty)
}

@Test
func authorizationAndSessionMismatchDoNotRestartOrTouchAnotherSession() async throws {
    let unauthorized = try CoordinatorFixture()
    defer { unauthorized.cleanup() }

    await #expect(throws: ThemeBridgeCoordinatorError.authorizationRequired) {
        _ = try await unauthorized.coordinator.apply(
            bundleURL: unauthorized.bundle.bundleURL,
            theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
            authorized: false,
            screenshotURL: nil
        )
    }
    #expect(unauthorized.restarter.prepareCount == 0)
    #expect(unauthorized.restarter.normalLaunches.isEmpty)
    #expect(unauthorized.session.startCount == 0)

    let mismatch = try CoordinatorFixture(
        initiallyActive: true,
        activeBundleURL: URL(fileURLWithPath: "/Users/test/Applications/ChatGPT.app")
    )
    defer { mismatch.cleanup() }

    await #expect(throws: ThemeBridgeCoordinatorError.activeSessionMismatch) {
        _ = try await mismatch.coordinator.apply(
            bundleURL: mismatch.bundle.bundleURL,
            theme: BridgeTheme(tokens: .workbench, artBlobURL: nil),
            authorized: true,
            screenshotURL: nil
        )
    }
    #expect(mismatch.session.stopCount == 0)
    #expect(mismatch.restarter.normalLaunches.isEmpty)
    #expect(mismatch.client.installedTargets.isEmpty)

    await #expect(throws: ThemeBridgeCoordinatorError.activeSessionMismatch) {
        try await mismatch.coordinator.restore(bundleURL: mismatch.bundle.bundleURL)
    }
    #expect(mismatch.session.stopCount == 0)
    #expect(mismatch.restarter.normalLaunches.isEmpty)
}

@Test
func maintainInstallsOnlyNewTargetsAndKeepsExistingTargetsIdempotent() async throws {
    let fixture = try CoordinatorFixture(initiallyActive: true)
    defer { fixture.cleanup() }

    let firstCount = try await fixture.coordinator.maintain(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil)
    )
    let secondCount = try await fixture.coordinator.maintain(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil)
    )

    #expect(firstCount == 1)
    #expect(secondCount == 0)
    #expect(fixture.client.installedTargets == [fixture.target])
    #expect(fixture.session.stopCount == 0)
    #expect(fixture.restarter.normalLaunches.isEmpty)
}

@Test
func aNewWatcherDoesNotRegisterAnotherBootstrapOnAnAlreadyStyledTarget() async throws {
    let fixture = try CoordinatorFixture(initiallyActive: true)
    defer { fixture.cleanup() }
    fixture.client.styledTargetIDs = [fixture.target.id]

    let count = try await fixture.coordinator.maintain(
        bundleURL: fixture.bundle.bundleURL,
        theme: BridgeTheme(tokens: .workbench, artBlobURL: nil)
    )

    #expect(count == 0)
    #expect(fixture.client.installedTargets.isEmpty)
}

@Test
@MainActor
func liveRestarterForceTerminatesOnlyTheVerifiedAppAfterGracefulTimeout() async throws {
    let bundleURL = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
    let application = StubRunningCodexApplication(
        bundleURL: bundleURL,
        acceptsGracefulTermination: false
    )
    let restarter = LiveCodexApplicationRestarter(
        applicationProvider: { _ in [application] },
        pause: {},
        gracefulAttempts: 1,
        forcedAttempts: 1
    )
    let bundle = VerifiedCodexBundle(
        bundleURL: bundleURL,
        executableURL: bundleURL.appending(path: "Contents/MacOS/ChatGPT"),
        bundleIdentifier: "com.openai.codex",
        teamIdentifier: "2DC432GLL2",
        version: "26.707.91948",
        architectures: [.current]
    )

    try await restarter.prepareForThemedLaunch(bundle)

    #expect(application.terminateCount == 1)
    #expect(application.forceTerminateCount == 1)
    #expect(application.isTerminated)
}

private final class CoordinatorFixture {
    let root: URL
    let bundle: VerifiedCodexBundle
    let target: CDPTarget
    let record: SessionRecord
    let session: StubThemeSession
    let client: StubCDPController
    let freshClient: StubCDPController
    let restarter: StubCodexRestarter
    let coordinator: ThemeBridgeCoordinator

    init(
        version: String = "26.707.91948",
        healthy: Bool = true,
        listenerOwned: Bool = true,
        initiallyActive: Bool = false,
        activeBundleURL: URL? = nil,
        usesFreshClientAfterFirstRequest: Bool = false,
        postInstallHealthy: Bool? = nil
    ) throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "ThemeBridgeCoordinatorTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let bundleURL = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
        let executableURL = bundleURL.appending(path: "Contents/MacOS/ChatGPT")
        bundle = VerifiedCodexBundle(
            bundleURL: bundleURL,
            executableURL: executableURL,
            bundleIdentifier: "com.openai.codex",
            teamIdentifier: "2DC432GLL2",
            version: version,
            architectures: [.current]
        )
        let process = ProcessIdentity(
            pid: 4_321,
            parentPID: 999,
            executableURL: executableURL,
            startTimeMicroseconds: 12_345_678
        )
        record = SessionRecord(
            bundleURL: activeBundleURL ?? bundleURL,
            bundleIdentifier: bundle.bundleIdentifier,
            bundleVersion: version,
            port: 55_000,
            process: process
        )
        target = CDPTarget(
            id: "page-1",
            type: "page",
            title: "Codex",
            url: URL(string: "app://codex/index.html")!,
            webSocketDebuggerURL: URL(
                string: "ws://127.0.0.1:55000/devtools/page/page-1"
            )!
        )
        session = StubThemeSession(record: record, initiallyActive: initiallyActive)
        let snapshot = LayoutHealthSnapshot(
            appShellVisible: healthy,
            sidebarVisible: healthy,
            mainSurfaceVisible: true,
            headerVisible: true,
            composerVisible: healthy,
            composerAcceptsPointerEvents: healthy,
            composerHitTestable: healthy,
            threadCanScroll: true,
            requiredSurfaceAnnotationsPresent: healthy,
            popoversWithinViewport: true,
            controlsWithinViewport: true,
            horizontalOverflowPixels: healthy ? 0 : 20
        )
        client = StubCDPController(
            targets: [target],
            snapshot: snapshot,
            screenshot: Data("screenshot".utf8)
        )
        if postInstallHealthy == false {
            client.snapshotSequencesByTargetID[target.id] = [
                snapshot,
                LayoutHealthSnapshot(
                    appShellVisible: true,
                    sidebarVisible: true,
                    mainSurfaceVisible: true,
                    headerVisible: true,
                    composerVisible: true,
                    composerAcceptsPointerEvents: true,
                    composerHitTestable: true,
                    threadCanScroll: true,
                    requiredSurfaceAnnotationsPresent: false,
                    popoversWithinViewport: true,
                    controlsWithinViewport: true,
                    horizontalOverflowPixels: 0
                ),
            ]
        }
        freshClient = StubCDPController(
            targets: [target],
            snapshot: snapshot,
            screenshot: Data("fresh screenshot".utf8)
        )
        restarter = StubCodexRestarter()
        coordinator = ThemeBridgeCoordinator(
            verifier: StubCoordinatorBundleVerifier(bundle: bundle),
            session: session,
            listenerVerifier: StubListenerVerifier(owned: listenerOwned),
            clientProvider: StubCDPProvider(
                clients: usesFreshClientAfterFirstRequest ? [client, freshClient] : [client]
            ),
            profileStore: try CompatibilityProfileStore.bundled(),
            compiler: try ThemeCompiler.bundled(),
            restarter: restarter,
            readinessAttempts: 1
        )
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

private struct StubCoordinatorBundleVerifier: CodexBundleVerifying {
    let bundle: VerifiedCodexBundle
    func verify(_ bundleURL: URL) throws -> VerifiedCodexBundle { bundle }
}

private final class StubThemeSession: ThemeSessionManaging, @unchecked Sendable {
    let record: SessionRecord
    var currentStatus: ThemeSessionStatus
    var startCount = 0
    var stopCount = 0
    var stopFails = false

    init(record: SessionRecord, initiallyActive: Bool) {
        self.record = record
        currentStatus = initiallyActive ? .active(record) : .inactive
    }

    func start(bundleURL: URL, authorized: Bool) throws -> SessionRecord {
        startCount += 1
        currentStatus = .active(record)
        return record
    }

    func status() -> ThemeSessionStatus { currentStatus }

    func stop() throws {
        stopCount += 1
        if stopFails { throw StubCoordinatorFailure() }
        currentStatus = .inactive
    }
}

private struct StubListenerVerifier: LoopbackListenerVerifying {
    let owned: Bool
    func verify(port: UInt16, owner: ProcessIdentity) throws -> Bool {
        if !owned { throw LoopbackListenerError.listenerNotOwned }
        return true
    }
}

private final class StubCDPController: CDPControlling, @unchecked Sendable {
    var targets: [CDPTarget]
    let snapshot: LayoutHealthSnapshot
    let screenshot: Data
    var snapshotsByTargetID: [String: LayoutHealthSnapshot] = [:]
    var snapshotSequencesByTargetID: [String: [LayoutHealthSnapshot]] = [:]
    var installedTargets: [CDPTarget] = []
    var installedHomeMarkers: [String] = []
    var installedAnnotationPlans: [HostSurfaceAnnotationPlan] = []
    var removedTargets: [CDPTarget] = []
    var removeAttempts: [CDPTarget] = []
    var removeFails = false
    var styledTargetIDs: Set<String> = []

    init(targets: [CDPTarget], snapshot: LayoutHealthSnapshot, screenshot: Data) {
        self.targets = targets
        self.snapshot = snapshot
        self.screenshot = screenshot
    }

    func listPageTargets() async throws -> [CDPTarget] { targets }
    func installStyle(
        _ css: String,
        homeMarker: String,
        annotations: HostSurfaceAnnotationPlan,
        on target: CDPTarget
    ) async throws {
        installedTargets.append(target)
        installedHomeMarkers.append(homeMarker)
        installedAnnotationPlans.append(annotations)
        styledTargetIDs.insert(target.id)
    }
    func isStyleInstalled(on target: CDPTarget) async throws -> Bool {
        styledTargetIDs.contains(target.id)
    }
    func removeStyle(from target: CDPTarget) async throws {
        removeAttempts.append(target)
        if removeFails { throw StubCoordinatorFailure() }
        removedTargets.append(target)
        styledTargetIDs.remove(target.id)
    }
    func healthSnapshot(
        on target: CDPTarget,
        check: LayoutHealthCheck
    ) async throws -> LayoutHealthSnapshot {
        if var sequence = snapshotSequencesByTargetID[target.id], !sequence.isEmpty {
            let next = sequence.removeFirst()
            snapshotSequencesByTargetID[target.id] = sequence
            return next
        }
        return snapshotsByTargetID[target.id] ?? snapshot
    }
    func captureScreenshot(of target: CDPTarget) async throws -> Data { screenshot }
}

private struct StubCoordinatorFailure: Error {}

private final class StubCDPProvider: CDPClientProviding, @unchecked Sendable {
    let clients: [StubCDPController]
    private var requestCount = 0

    init(clients: [StubCDPController]) {
        self.clients = clients
    }

    func client(port: UInt16) -> any CDPControlling {
        let client = clients[min(requestCount, clients.count - 1)]
        requestCount += 1
        return client
    }
}

private final class StubCodexRestarter: CodexApplicationRestarting, @unchecked Sendable {
    var prepareCount = 0
    var normalLaunches: [URL] = []

    func prepareForThemedLaunch(_ bundle: VerifiedCodexBundle) async throws {
        prepareCount += 1
    }
    func launchNormally(bundleURL: URL) throws { normalLaunches.append(bundleURL) }
}

@MainActor
private final class StubRunningCodexApplication: RunningCodexApplication, @unchecked Sendable {
    let bundleURL: URL?
    let acceptsGracefulTermination: Bool
    var isTerminated = false
    var terminateCount = 0
    var forceTerminateCount = 0

    init(bundleURL: URL, acceptsGracefulTermination: Bool) {
        self.bundleURL = bundleURL
        self.acceptsGracefulTermination = acceptsGracefulTermination
    }

    func terminate() -> Bool {
        terminateCount += 1
        return acceptsGracefulTermination
    }

    func forceTerminate() -> Bool {
        forceTerminateCount += 1
        isTerminated = true
        return true
    }
}

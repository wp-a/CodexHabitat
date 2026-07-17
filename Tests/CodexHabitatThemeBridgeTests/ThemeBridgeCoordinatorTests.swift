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

    #expect(fixture.client.removedTargets == [fixture.target])
    #expect(fixture.session.stopCount == 1)
    #expect(fixture.restarter.normalLaunches == [fixture.bundle.bundleURL])
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
    #expect(unknown.session.stopCount == 1)
    #expect(unknown.restarter.normalLaunches == [unknown.bundle.bundleURL])

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
func restoreRemovesInjectedStyleStopsExactSessionAndLaunchesOfficialApp() async throws {
    let fixture = try CoordinatorFixture(initiallyActive: true)
    defer { fixture.cleanup() }

    try await fixture.coordinator.restore(bundleURL: fixture.bundle.bundleURL)

    #expect(fixture.client.removedTargets == [fixture.target])
    #expect(fixture.session.stopCount == 1)
    #expect(fixture.restarter.normalLaunches == [fixture.bundle.bundleURL])
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

private final class CoordinatorFixture {
    let root: URL
    let bundle: VerifiedCodexBundle
    let target: CDPTarget
    let record: SessionRecord
    let session: StubThemeSession
    let client: StubCDPController
    let restarter: StubCodexRestarter
    let coordinator: ThemeBridgeCoordinator

    init(
        version: String = "26.707.91948",
        healthy: Bool = true,
        listenerOwned: Bool = true,
        initiallyActive: Bool = false,
        activeBundleURL: URL? = nil
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
            sidebarVisible: healthy,
            mainSurfaceVisible: true,
            composerVisible: healthy,
            composerAcceptsPointerEvents: healthy,
            threadCanScroll: true,
            popoversWithinViewport: true,
            controlsWithinViewport: true,
            horizontalOverflowPixels: healthy ? 0 : 20
        )
        client = StubCDPController(
            targets: [target],
            snapshot: snapshot,
            screenshot: Data("screenshot".utf8)
        )
        restarter = StubCodexRestarter()
        coordinator = ThemeBridgeCoordinator(
            verifier: StubCoordinatorBundleVerifier(bundle: bundle),
            session: session,
            listenerVerifier: StubListenerVerifier(owned: listenerOwned),
            clientProvider: StubCDPProvider(client: client),
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
    let targets: [CDPTarget]
    let snapshot: LayoutHealthSnapshot
    let screenshot: Data
    var installedTargets: [CDPTarget] = []
    var removedTargets: [CDPTarget] = []

    init(targets: [CDPTarget], snapshot: LayoutHealthSnapshot, screenshot: Data) {
        self.targets = targets
        self.snapshot = snapshot
        self.screenshot = screenshot
    }

    func listPageTargets() async throws -> [CDPTarget] { targets }
    func installStyle(_ css: String, on target: CDPTarget) async throws {
        installedTargets.append(target)
    }
    func removeStyle(from target: CDPTarget) async throws { removedTargets.append(target) }
    func healthSnapshot(
        on target: CDPTarget,
        check: LayoutHealthCheck
    ) async throws -> LayoutHealthSnapshot { snapshot }
    func captureScreenshot(of target: CDPTarget) async throws -> Data { screenshot }
}

private struct StubCDPProvider: CDPClientProviding {
    let client: StubCDPController
    func client(port: UInt16) -> any CDPControlling { client }
}

private final class StubCodexRestarter: CodexApplicationRestarting, @unchecked Sendable {
    var prepareCount = 0
    var normalLaunches: [URL] = []

    func prepareForThemedLaunch(_ bundle: VerifiedCodexBundle) async throws {
        prepareCount += 1
    }
    func launchNormally(bundleURL: URL) throws { normalLaunches.append(bundleURL) }
}

import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@MainActor
struct ThemeBridgeIntegrationModelTests {
    @Test
    func refreshVerifiesHelperAndReportsInactiveOrActiveSession() async {
        let inactiveRunner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "verified"),
            ThemeBridgeCommandResult(exitCode: 0, output: "inactive"),
        ])
        let inactive = ThemeBridgeIntegrationModel(runner: inactiveRunner)
        await inactive.refresh()
        #expect(inactive.state == .ready)
        #expect(inactive.canApply)
        #expect(!inactive.canRestore)
        #expect(inactiveRunner.invocations == [["verify"], ["status"]])

        let activeRunner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "verified"),
            ThemeBridgeCommandResult(exitCode: 0, output: "active: pid=42 port=55000"),
        ])
        let active = ThemeBridgeIntegrationModel(runner: activeRunner)
        await active.refresh()
        #expect(active.state == .active)
        #expect(active.canApply)
        #expect(active.canRestore)
        #expect(active.activeThemeID == nil)
    }

    @Test
    func concurrentRefreshRequestsShareOneVerifyAndStatusSequence() async {
        let probe = RefreshInvocationProbe()
        let runner = CoalescingThemeBridgeRunner(probe: probe)
        let model = ThemeBridgeIntegrationModel(runner: runner)

        async let first: Void = model.refresh()
        async let second: Void = model.refresh()
        _ = await (first, second)

        #expect(await probe.invocations == [["verify"], ["status"]])
        #expect(model.state == .ready)
    }

    @Test
    func staleRefreshGenerationCannotReplaceTheCurrentGeneration() {
        var generation = ThemeBridgeRefreshGeneration()

        let stale = generation.begin()
        let current = generation.begin()

        #expect(!generation.accepts(stale))
        #expect(generation.accepts(current))
    }

    @Test
    func helperCommandTerminatesAtItsConfiguredTimeout() async {
        let runner = ThemeBridgeHelperRunner(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            commandTimeout: .milliseconds(30)
        )
        let clock = ContinuousClock()
        let started = clock.now

        await #expect(throws: ThemeBridgeCommandError.timedOut) {
            try await runner.run(arguments: ["2"])
        }

        #expect(clock.now - started < .milliseconds(500))
    }

    @Test
    func helperCommandForceTerminatesAProcessThatIgnoresTermination() async {
        let runner = ThemeBridgeHelperRunner(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            commandTimeout: .milliseconds(30)
        )
        let clock = ContinuousClock()
        let started = clock.now

        await #expect(throws: ThemeBridgeCommandError.timedOut) {
            try await runner.run(arguments: [
                "-c", "trap '' TERM; exec /bin/sleep 2",
            ])
        }

        #expect(clock.now - started < .milliseconds(500))
    }

    @Test
    func activeSessionCanApplyAnotherThemeAndMoveTheWatcher() async {
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "applied"),
            ThemeBridgeCommandResult(exitCode: 0, output: "applied"),
        ])
        let model = ThemeBridgeIntegrationModel(runner: runner)

        await model.enable(themeID: "workbench")
        await model.enable(themeID: "night-shift")

        #expect(model.state == .active)
        #expect(model.activeThemeID == "night-shift")
        #expect(model.canApply)
        #expect(runner.invocations == [
            ["apply", "--authorized", "--theme", "workbench"],
            ["apply", "--authorized", "--theme", "night-shift"],
        ])
        #expect(runner.watchedThemes == ["workbench", "night-shift"])
    }

    @Test
    func enableRequiresModelConfirmationCallAndPassesOnlyApprovedArguments() async {
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "applied"),
        ])
        let model = ThemeBridgeIntegrationModel(runner: runner)

        await model.enable(themeID: "night-shift")

        #expect(model.state == .active)
        #expect(runner.invocations == [[
            "apply", "--authorized", "--theme", "night-shift",
        ]])
        #expect(runner.watchedThemes == ["night-shift"])
    }

    @Test
    func allBuiltInsAndOnlyExplicitlyValidatedCustomThemesCanReachTheHelper() async {
        for themeID in BuiltInThemeCatalog.all.map(\.id) {
            let runner = StubThemeBridgeRunner(results: [
                ThemeBridgeCommandResult(exitCode: 0, output: "applied"),
            ])
            let model = ThemeBridgeIntegrationModel(runner: runner)
            await model.enable(themeID: themeID)
            #expect(model.state == .active)
        }

        let customID = "local.theme.bridge-test"
        let rejectedRunner = StubThemeBridgeRunner(results: [])
        let rejected = ThemeBridgeIntegrationModel(runner: rejectedRunner)
        await rejected.enable(themeID: customID)
        #expect(rejected.state == .failed)
        #expect(rejectedRunner.invocations.isEmpty)

        let approvedRunner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "applied"),
        ])
        let approved = ThemeBridgeIntegrationModel(runner: approvedRunner)
        await approved.enable(themeID: customID, approvedThemeIDs: [customID])
        #expect(approved.state == .active)
        #expect(approvedRunner.invocations == [[
            "apply", "--authorized", "--theme", customID,
        ]])
    }

    @Test
    func restoreReturnsToReadyAndFailuresStayStable() async {
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "restored"),
            ThemeBridgeCommandResult(exitCode: 1, output: "sensitive raw helper error"),
        ])
        let model = ThemeBridgeIntegrationModel(runner: runner)

        await model.restore()
        #expect(model.state == .ready)
        #expect(model.activeThemeID == nil)
        await model.enable(themeID: "workbench")
        #expect(model.state == .failed)
        #expect(model.canApply)
        #expect(model.canRestore)
        #expect(model.statusText == "Theme bridge action failed")
        #expect(model.failure == .unknown)
        #expect(!model.statusText.contains("sensitive"))
    }

    @Test
    func resumedWatcherRecordsThePersistedThemeAsActive() async {
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "verified"),
            ThemeBridgeCommandResult(exitCode: 0, output: "active: pid=42 port=55000"),
        ])
        let model = ThemeBridgeIntegrationModel(runner: runner)

        await model.refresh()
        await model.resumeWatching(themeID: "workbench")

        #expect(model.state == .active)
        #expect(model.activeThemeID == "workbench")
        #expect(runner.watchedThemes == ["workbench"])
    }

    @Test
    func activeStatusRefreshRetainsAWatcherConfirmedThemeID() async {
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "applied"),
            ThemeBridgeCommandResult(exitCode: 0, output: "verified"),
            ThemeBridgeCommandResult(exitCode: 0, output: "active: pid=42 port=55000"),
        ])
        let model = ThemeBridgeIntegrationModel(runner: runner)

        await model.enable(themeID: "workbench")
        await model.refresh()

        #expect(model.state == .active)
        #expect(model.activeThemeID == "workbench")
    }

    @Test
    func knownHelperFailureIsShownSafelyAndRecordedLocally() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "ThemeBridgeDiagnostics-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticStore(root: root)
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(
                exitCode: 1,
                output: "theme-bridge: code=targetUnavailable"
            ),
        ])
        let model = ThemeBridgeIntegrationModel(
            runner: runner,
            diagnosticStore: store,
            appVersion: "0.1.0"
        )

        await model.enable(themeID: "workbench")

        #expect(model.state == .failed)
        #expect(model.failure == .targetUnavailable)
        #expect(model.statusText == "Codex theme surface was not ready in time")
        let events = try await store.events()
        #expect(events.map(\.code) == [.themeTargetUnavailable])
    }

    @Test
    func stableHelperStageCodesMapToDistinctFailures() {
        #expect(ThemeBridgeFailure.classify(
            helperOutput: "theme-bridge: code=listenerUnavailable"
        ) == .listenerUnavailable)
        #expect(ThemeBridgeFailure.classify(
            helperOutput: "theme-bridge: code=targetUnavailable"
        ) == .targetUnavailable)
        #expect(ThemeBridgeFailure.classify(
            helperOutput: "theme-bridge: code=runtimeUnavailable"
        ) == .runtimeUnavailable)
        #expect(ThemeBridgeFailure.classify(
            helperOutput: "theme-bridge: code=domHealthRejected"
        ) == .layoutRejected)
        #expect(ThemeBridgeFailure.classify(
            helperOutput: "theme-bridge: code=processRejected"
        ) == .processRejected)
    }

    @Test
    func runtimeFailureIsShownSafelyAndRecordedLocally() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "ThemeBridgeRuntimeDiagnostics-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticStore(root: root)
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(
                exitCode: 1,
                output: "theme-bridge: code=runtimeUnavailable"
            ),
        ])
        let model = ThemeBridgeIntegrationModel(
            runner: runner,
            diagnosticStore: store,
            appVersion: "0.1.0"
        )

        await model.enable(themeID: "workbench")

        #expect(model.state == .failed)
        #expect(model.failure == .runtimeUnavailable)
        #expect(model.statusText == "Codex theme runtime connection failed")
        let events = try await store.events()
        #expect(events.map(\.code) == [.themeRuntimeUnavailable])
    }

    @Test
    func applicationTerminationRestoresAnActiveBridgeSession() async {
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "verified"),
            ThemeBridgeCommandResult(exitCode: 0, output: "active: pid=42 port=55000"),
            ThemeBridgeCommandResult(exitCode: 0, output: "restored"),
        ])
        let model = ThemeBridgeIntegrationModel(runner: runner)

        await model.restoreForApplicationTermination()

        #expect(model.state == .ready)
        #expect(runner.invocations == [["verify"], ["status"], ["restore"]])
        #expect(runner.stopWatchingCount == 1)
    }

    @Test
    func watcherExitCannotLeaveTheBridgeReportedAsActive() async {
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "applied"),
            ThemeBridgeCommandResult(exitCode: 0, output: "restored"),
        ])
        runner.watchRunning = false
        let model = ThemeBridgeIntegrationModel(runner: runner)

        await model.enable(themeID: "workbench")

        #expect(model.state == .failed)
        #expect(runner.invocations == [
            ["apply", "--authorized", "--theme", "workbench"],
            ["restore"],
        ])
    }
}

private final class StubThemeBridgeRunner: ThemeBridgeCommandExecuting, @unchecked Sendable {
    var results: [ThemeBridgeCommandResult]
    var invocations: [[String]] = []
    var watchedThemes: [String] = []
    var stopWatchingCount = 0
    var watchRunning = true

    init(results: [ThemeBridgeCommandResult]) { self.results = results }

    func run(arguments: [String]) async throws -> ThemeBridgeCommandResult {
        invocations.append(arguments)
        return results.removeFirst()
    }

    func startWatching(themeID: String) throws {
        watchedThemes.append(themeID)
    }

    func stopWatching() {
        stopWatchingCount += 1
    }

    func isWatching() -> Bool {
        watchRunning
    }

    func confirmWatching() async -> Bool {
        watchRunning
    }
}

private actor RefreshInvocationProbe {
    private(set) var invocations: [[String]] = []

    func run(arguments: [String]) async -> ThemeBridgeCommandResult {
        invocations.append(arguments)
        try? await Task.sleep(for: .milliseconds(20))
        return ThemeBridgeCommandResult(
            exitCode: 0,
            output: arguments == ["status"] ? "inactive" : "verified"
        )
    }
}

private final class CoalescingThemeBridgeRunner: ThemeBridgeCommandExecuting, @unchecked Sendable {
    private let probe: RefreshInvocationProbe

    init(probe: RefreshInvocationProbe) {
        self.probe = probe
    }

    func run(arguments: [String]) async throws -> ThemeBridgeCommandResult {
        await probe.run(arguments: arguments)
    }

    func startWatching(themeID _: String) throws {}
    func stopWatching() {}
    func isWatching() -> Bool { false }
    func confirmWatching() async -> Bool { false }
}

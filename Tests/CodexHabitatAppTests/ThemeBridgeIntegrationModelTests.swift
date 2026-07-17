import Foundation
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
        #expect(!inactive.canRestore)
        #expect(inactiveRunner.invocations == [["verify"], ["status"]])

        let activeRunner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "verified"),
            ThemeBridgeCommandResult(exitCode: 0, output: "active: pid=42 port=55000"),
        ])
        let active = ThemeBridgeIntegrationModel(runner: activeRunner)
        await active.refresh()
        #expect(active.state == .active)
        #expect(active.canRestore)
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
    func restoreReturnsToReadyAndFailuresStayStable() async {
        let runner = StubThemeBridgeRunner(results: [
            ThemeBridgeCommandResult(exitCode: 0, output: "restored"),
            ThemeBridgeCommandResult(exitCode: 1, output: "sensitive raw helper error"),
        ])
        let model = ThemeBridgeIntegrationModel(runner: runner)

        await model.restore()
        #expect(model.state == .ready)
        await model.enable(themeID: "workbench")
        #expect(model.state == .failed)
        #expect(model.canRestore)
        #expect(model.statusText == "Theme bridge action failed")
        #expect(!model.statusText.contains("sensitive"))
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
}

private final class StubThemeBridgeRunner: ThemeBridgeCommandExecuting, @unchecked Sendable {
    var results: [ThemeBridgeCommandResult]
    var invocations: [[String]] = []
    var watchedThemes: [String] = []
    var stopWatchingCount = 0

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
}

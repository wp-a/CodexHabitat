import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func listenerMustBeLoopbackAndOwnedByTheRecordedProcessTree() throws {
    let rootProcess = ProcessIdentity(
        pid: 100,
        parentPID: 1,
        executableURL: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"),
        startTimeMicroseconds: 100
    )
    let child = ProcessIdentity(
        pid: 101,
        parentPID: 100,
        executableURL: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/MacOS/Helper"),
        startTimeMicroseconds: 101
    )
    let inspector = CodexProcessInspector { pid in
        [100: rootProcess, 101: child][pid]
    }
    let runner = StubBridgeCommandRunner(result: BridgeCommandResult(
        exitCode: 0,
        standardOutput: "p101\nn127.0.0.1:55000\n"
    ))
    let verifier = LoopbackListenerVerifier(commandRunner: runner, processInspector: inspector)

    #expect(try verifier.verify(port: 55_000, owner: rootProcess))
    #expect(runner.arguments == [
        "-nP", "-a", "-iTCP:55000", "-sTCP:LISTEN", "-FpFn",
    ])
}

@Test(arguments: [
    "p101\nn*:55000\n",
    "p101\nn0.0.0.0:55000\n",
    "p999\nn127.0.0.1:55000\n",
    "",
])
func wildcardUnrelatedAndMissingListenersAreRejected(_ output: String) {
    let owner = ProcessIdentity(
        pid: 100,
        parentPID: 1,
        executableURL: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"),
        startTimeMicroseconds: 100
    )
    let child = ProcessIdentity(
        pid: 101,
        parentPID: 100,
        executableURL: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/MacOS/Helper"),
        startTimeMicroseconds: 101
    )
    let inspector = CodexProcessInspector { pid in
        [100: owner, 101: child][pid]
    }
    let verifier = LoopbackListenerVerifier(
        commandRunner: StubBridgeCommandRunner(result: BridgeCommandResult(
            exitCode: 0,
            standardOutput: output
        )),
        processInspector: inspector
    )

    #expect(throws: LoopbackListenerError.listenerNotOwned) {
        try verifier.verify(port: 55_000, owner: owner)
    }
}

private final class StubBridgeCommandRunner: BridgeCommandRunning, @unchecked Sendable {
    let result: BridgeCommandResult
    var arguments: [String] = []

    init(result: BridgeCommandResult) { self.result = result }

    func run(executable: URL, arguments: [String]) throws -> BridgeCommandResult {
        #expect(executable.path == "/usr/sbin/lsof")
        self.arguments = arguments
        return result
    }
}

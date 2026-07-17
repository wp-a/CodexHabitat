import Foundation

struct BridgeCommandResult: Equatable, Sendable {
    let exitCode: Int32
    let standardOutput: String
}

protocol BridgeCommandRunning: AnyObject, Sendable {
    func run(executable: URL, arguments: [String]) throws -> BridgeCommandResult
}

enum LoopbackListenerError: Error, Equatable {
    case inspectionFailed
    case listenerNotOwned
}

protocol LoopbackListenerVerifying: Sendable {
    func verify(port: UInt16, owner: ProcessIdentity) throws -> Bool
}

struct LoopbackListenerVerifier: LoopbackListenerVerifying {
    private let commandRunner: any BridgeCommandRunning
    private let processInspector: any CodexProcessInspecting

    init(
        commandRunner: any BridgeCommandRunning,
        processInspector: any CodexProcessInspecting
    ) {
        self.commandRunner = commandRunner
        self.processInspector = processInspector
    }

    func verify(port: UInt16, owner: ProcessIdentity) throws -> Bool {
        let result = try commandRunner.run(
            executable: URL(fileURLWithPath: "/usr/sbin/lsof"),
            arguments: [
                "-nP", "-a", "-iTCP:\(port)", "-sTCP:LISTEN", "-FpFn",
            ]
        )
        guard result.exitCode == 0 else {
            throw LoopbackListenerError.listenerNotOwned
        }
        let listeners = Self.parse(result.standardOutput)
        guard !listeners.isEmpty,
              listeners.allSatisfy({ listener in
                  listener.address == "127.0.0.1:\(port)"
                      && processInspector.isDescendant(listener.pid, of: owner.pid)
              })
        else {
            throw LoopbackListenerError.listenerNotOwned
        }
        return true
    }

    private static func parse(_ output: String) -> [(pid: Int32, address: String)] {
        var currentPID: Int32?
        var result: [(Int32, String)] = []
        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix("p"), let pid = Int32(line.dropFirst()) {
                currentPID = pid
            } else if line.hasPrefix("n"), let currentPID {
                result.append((currentPID, String(line.dropFirst())))
            }
        }
        return result
    }
}

final class LiveBridgeCommandRunner: BridgeCommandRunning, @unchecked Sendable {
    func run(executable: URL, arguments: [String]) throws -> BridgeCommandResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard data.count <= 256 * 1024 else {
            throw LoopbackListenerError.inspectionFailed
        }
        return BridgeCommandResult(
            exitCode: process.terminationStatus,
            standardOutput: String(data: data, encoding: .utf8) ?? ""
        )
    }
}

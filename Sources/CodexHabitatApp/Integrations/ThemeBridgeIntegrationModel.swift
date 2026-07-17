import Foundation

struct ThemeBridgeCommandResult: Equatable, Sendable {
    let exitCode: Int32
    let output: String
}

protocol ThemeBridgeCommandExecuting: Sendable {
    func run(arguments: [String]) async throws -> ThemeBridgeCommandResult
}

enum ThemeBridgeIntegrationState: Equatable {
    case unavailable
    case checking
    case ready
    case applying
    case active
    case restoring
    case failed
}

@MainActor
final class ThemeBridgeIntegrationModel: ObservableObject {
    @Published private(set) var state = ThemeBridgeIntegrationState.checking

    private let runner: (any ThemeBridgeCommandExecuting)?

    var statusText: String {
        switch state {
        case .unavailable: "Helper unavailable"
        case .checking: "Checking official Codex"
        case .ready: "Ready"
        case .applying: "Restarting and checking layout"
        case .active: "Theme session active"
        case .restoring: "Restoring official appearance"
        case .failed: "Theme bridge action failed"
        }
    }

    var isBusy: Bool {
        [.checking, .applying, .restoring].contains(state)
    }

    var canRestore: Bool {
        runner != nil && [.active, .failed].contains(state)
    }

    init(runner: (any ThemeBridgeCommandExecuting)?) {
        self.runner = runner
        if runner == nil { state = .unavailable }
    }

    static func live() -> ThemeBridgeIntegrationModel {
        ThemeBridgeIntegrationModel(runner: ThemeBridgeHelperRunner.locate())
    }

    func refresh() async {
        guard let runner else {
            state = .unavailable
            return
        }
        state = .checking
        do {
            let verification = try await runner.run(arguments: ["verify"])
            guard verification.exitCode == 0 else {
                state = .unavailable
                return
            }
            let status = try await runner.run(arguments: ["status"])
            guard status.exitCode == 0 else {
                state = .failed
                return
            }
            state = status.output.hasPrefix("active:") ? .active : .ready
        } catch {
            state = .unavailable
        }
    }

    func enable(themeID: String) async {
        guard let runner,
              ["workbench", "night-shift", "arcade-signal", "quiet-garden"]
                .contains(themeID)
        else {
            state = .failed
            return
        }
        state = .applying
        do {
            let result = try await runner.run(arguments: [
                "apply", "--authorized", "--theme", themeID,
            ])
            state = result.exitCode == 0 ? .active : .failed
        } catch {
            state = .failed
        }
    }

    func restore() async {
        guard let runner else {
            state = .unavailable
            return
        }
        state = .restoring
        do {
            let result = try await runner.run(arguments: ["restore"])
            state = result.exitCode == 0 ? .ready : .failed
        } catch {
            state = .failed
        }
    }
}

private struct ThemeBridgeHelperRunner: ThemeBridgeCommandExecuting {
    let executableURL: URL

    static func locate(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> ThemeBridgeHelperRunner? {
        var candidates: [URL] = []
        candidates.append(
            bundle.bundleURL.appending(
                path: "Contents/Helpers/CodexHabitatThemeBridge"
            )
        )
        if let executable = bundle.executableURL {
            candidates.append(
                executable.deletingLastPathComponent().appending(
                    path: "CodexHabitatThemeBridge"
                )
            )
        }
        for candidate in candidates {
            guard fileManager.isExecutableFile(atPath: candidate.path),
                  let values = try? candidate.resourceValues(
                    forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
                  ),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true
            else {
                continue
            }
            return ThemeBridgeHelperRunner(executableURL: candidate)
        }
        return nil
    }

    func run(arguments: [String]) async throws -> ThemeBridgeCommandResult {
        try await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            try process.run()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let bounded = output.prefix(64 * 1024)
            return ThemeBridgeCommandResult(
                exitCode: process.terminationStatus,
                output: String(decoding: bounded, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }.value
    }
}

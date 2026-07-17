import Foundation

struct ThemeBridgeCommandResult: Equatable, Sendable {
    let exitCode: Int32
    let output: String
}

protocol ThemeBridgeCommandExecuting: Sendable {
    func run(arguments: [String]) async throws -> ThemeBridgeCommandResult
    func startWatching(themeID: String) throws
    func stopWatching()
    func isWatching() -> Bool
    func confirmWatching() async -> Bool
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

    static let shared = ThemeBridgeIntegrationModel.live()

    private let runner: (any ThemeBridgeCommandExecuting)?
    private var watchHealthTask: Task<Void, Never>?

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
            guard result.exitCode == 0 else {
                state = .failed
                return
            }
            do {
                try runner.startWatching(themeID: themeID)
                guard await runner.confirmWatching() else {
                    stopWatching()
                    _ = try? await runner.run(arguments: ["restore"])
                    state = .failed
                    return
                }
                state = .active
                startWatchHealthMonitor()
            } catch {
                _ = try? await runner.run(arguments: ["restore"])
                state = .failed
            }
        } catch {
            state = .failed
        }
    }

    func restore() async {
        guard let runner else {
            state = .unavailable
            return
        }
        stopWatching()
        state = .restoring
        do {
            let result = try await runner.run(arguments: ["restore"])
            state = result.exitCode == 0 ? .ready : .failed
        } catch {
            state = .failed
        }
    }

    func restoreForApplicationTermination() async {
        await refresh()
        guard state == .active else { return }
        await restore()
    }

    func resumeWatching(themeID: String) async {
        guard state == .active,
              ["workbench", "night-shift", "arcade-signal", "quiet-garden"]
                .contains(themeID),
              let runner
        else {
            return
        }
        do {
            try runner.startWatching(themeID: themeID)
            guard await runner.confirmWatching() else {
                stopWatching()
                state = .failed
                return
            }
            startWatchHealthMonitor()
        } catch {
            state = .failed
        }
    }

    private func startWatchHealthMonitor() {
        watchHealthTask?.cancel()
        watchHealthTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self else { return }
                self.refreshWatchHealth()
                guard self.state == .active else { return }
            }
        }
    }

    private func refreshWatchHealth() {
        guard state == .active, let runner, !runner.isWatching() else { return }
        stopWatching()
        state = .failed
    }

    private func stopWatching() {
        watchHealthTask?.cancel()
        watchHealthTask = nil
        runner?.stopWatching()
    }
}

private final class ThemeBridgeHelperRunner: ThemeBridgeCommandExecuting, @unchecked Sendable {
    let executableURL: URL
    private var watchProcess: Process?

    init(executableURL: URL) {
        self.executableURL = executableURL
    }

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
        let executableURL = executableURL
        return try await Task.detached {
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

    func startWatching(themeID: String) throws {
        stopWatching()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "watch",
            "--theme", themeID,
            "--parent-pid", String(ProcessInfo.processInfo.processIdentifier),
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        watchProcess = process
    }

    func stopWatching() {
        guard let process = watchProcess else { return }
        if process.isRunning {
            process.terminate()
        }
        watchProcess = nil
    }

    func isWatching() -> Bool {
        watchProcess?.isRunning == true
    }

    func confirmWatching() async -> Bool {
        guard isWatching() else { return false }
        do {
            try await Task.sleep(for: .milliseconds(150))
        } catch {
            return false
        }
        return isWatching()
    }
}

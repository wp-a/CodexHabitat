import Foundation
import HabitatCore

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

enum ThemeBridgeFailure: Equatable {
    case listenerUnavailable
    case targetUnavailable
    case runtimeUnavailable
    case layoutRejected
    case processRejected
    case unsupportedVersion
    case watcherUnavailable
    case unknown

    var statusText: String {
        switch self {
        case .listenerUnavailable: "Codex did not open the local theme port"
        case .targetUnavailable: "Codex theme surface was not ready in time"
        case .runtimeUnavailable: "Codex theme runtime connection failed"
        case .layoutRejected: "Codex layout safety check rejected the theme"
        case .processRejected: "Codex theme process could not be verified"
        case .unsupportedVersion: "This Codex version is not supported"
        case .watcherUnavailable: "Theme monitor did not start"
        case .unknown: "Theme bridge action failed"
        }
    }

    var diagnosticCode: DiagnosticCode {
        switch self {
        case .listenerUnavailable: .themeListenerUnavailable
        case .targetUnavailable: .themeTargetUnavailable
        case .runtimeUnavailable: .themeRuntimeUnavailable
        case .layoutRejected: .themeLayoutRejected
        case .processRejected: .themeProcessRejected
        case .unsupportedVersion: .themeUnsupportedVersion
        case .watcherUnavailable: .themeWatchFailed
        case .unknown: .themeApplyFailed
        }
    }

    static func classify(helperOutput: String) -> ThemeBridgeFailure {
        let marker = "theme-bridge: code="
        guard helperOutput.hasPrefix(marker) else { return .unknown }
        switch helperOutput.dropFirst(marker.count) {
        case "listenerUnavailable": return .listenerUnavailable
        case "targetUnavailable": return .targetUnavailable
        case "runtimeUnavailable": return .runtimeUnavailable
        case "domHealthRejected": return .layoutRejected
        case "processRejected": return .processRejected
        case "unsupportedVersion": return .unsupportedVersion
        default: return .unknown
        }
    }
}

@MainActor
final class ThemeBridgeIntegrationModel: ObservableObject {
    @Published private(set) var state = ThemeBridgeIntegrationState.checking
    @Published private(set) var failure: ThemeBridgeFailure?
    @Published private(set) var activeThemeID: String?

    static let shared = ThemeBridgeIntegrationModel.live()

    private let runner: (any ThemeBridgeCommandExecuting)?
    private let diagnosticStore: DiagnosticStore?
    private let appVersion: String?
    private var watchHealthTask: Task<Void, Never>?
    private static let builtInThemeIDs = Set(BuiltInThemeCatalog.all.map(\.id))

    var statusText: String {
        switch state {
        case .unavailable: "Helper unavailable"
        case .checking: "Checking official Codex"
        case .ready: "Ready"
        case .applying: "Applying and checking layout"
        case .active: "Theme session active"
        case .restoring: "Restoring official appearance"
        case .failed: failure?.statusText ?? "Theme bridge action failed"
        }
    }

    var isBusy: Bool {
        [.checking, .applying, .restoring].contains(state)
    }

    var canApply: Bool {
        runner != nil && [.ready, .active, .failed].contains(state)
    }

    var canRestore: Bool {
        runner != nil && [.active, .failed].contains(state)
    }

    init(
        runner: (any ThemeBridgeCommandExecuting)?,
        diagnosticStore: DiagnosticStore? = nil,
        appVersion: String? = nil
    ) {
        self.runner = runner
        self.diagnosticStore = diagnosticStore
        self.appVersion = appVersion
        if runner == nil { state = .unavailable }
    }

    static func live(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> ThemeBridgeIntegrationModel {
        let root: URL
        if let configured = environment["CODEX_HABITAT_HOME"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !configured.isEmpty {
            root = URL(fileURLWithPath: configured, isDirectory: true)
        } else {
            let support = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.homeDirectoryForCurrentUser.appending(
                path: "Library/Application Support",
                directoryHint: .isDirectory
            )
            root = support.appending(path: "Codex Habitat", directoryHint: .isDirectory)
        }
        let version = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        return ThemeBridgeIntegrationModel(
            runner: ThemeBridgeHelperRunner.locate(bundle: bundle, fileManager: fileManager),
            diagnosticStore: DiagnosticStore(root: AppDirectories(root: root).diagnostics),
            appVersion: version
        )
    }

    func refresh() async {
        guard let runner else {
            state = .unavailable
            activeThemeID = nil
            return
        }
        let confirmedActiveThemeID = activeThemeID
        state = .checking
        failure = nil
        do {
            let verification = try await runner.run(arguments: ["verify"])
            guard verification.exitCode == 0 else {
                state = .unavailable
                activeThemeID = nil
                return
            }
            let status = try await runner.run(arguments: ["status"])
            guard status.exitCode == 0 else {
                state = .failed
                activeThemeID = nil
                return
            }
            if status.output.hasPrefix("active:") {
                state = .active
                activeThemeID = confirmedActiveThemeID
            } else {
                state = .ready
                activeThemeID = nil
            }
        } catch {
            state = .unavailable
            activeThemeID = nil
        }
    }

    func enable(themeID: String, approvedThemeIDs: Set<String> = []) async {
        guard let runner,
              Self.builtInThemeIDs.contains(themeID) || approvedThemeIDs.contains(themeID)
        else {
            await fail(.processRejected)
            return
        }
        state = .applying
        failure = nil
        do {
            let result = try await runner.run(arguments: [
                "apply", "--authorized", "--theme", themeID,
            ])
            guard result.exitCode == 0 else {
                await fail(.classify(helperOutput: result.output))
                return
            }
            do {
                try runner.startWatching(themeID: themeID)
                guard await runner.confirmWatching() else {
                    stopWatching()
                    _ = try? await runner.run(arguments: ["restore"])
                    await fail(.watcherUnavailable)
                    return
                }
                state = .active
                activeThemeID = themeID
                await record(.themeApplied)
                startWatchHealthMonitor()
            } catch {
                _ = try? await runner.run(arguments: ["restore"])
                await fail(.watcherUnavailable)
            }
        } catch {
            await fail(.unknown)
        }
    }

    func restore() async {
        guard let runner else {
            state = .unavailable
            activeThemeID = nil
            return
        }
        stopWatching()
        state = .restoring
        activeThemeID = nil
        do {
            let result = try await runner.run(arguments: ["restore"])
            if result.exitCode == 0 {
                failure = nil
                state = .ready
                await record(.themeRestored)
            } else {
                failure = .unknown
                state = .failed
                await record(.themeRestoreFailed)
            }
        } catch {
            failure = .unknown
            state = .failed
            await record(.themeRestoreFailed)
        }
    }

    func restoreForApplicationTermination() async {
        await refresh()
        guard state == .active else { return }
        await restore()
    }

    func resumeWatching(themeID: String, approvedThemeIDs: Set<String> = []) async {
        guard state == .active,
              Self.builtInThemeIDs.contains(themeID) || approvedThemeIDs.contains(themeID),
              let runner
        else {
            return
        }
        do {
            try runner.startWatching(themeID: themeID)
            guard await runner.confirmWatching() else {
                stopWatching()
                await fail(.watcherUnavailable)
                return
            }
            activeThemeID = themeID
            startWatchHealthMonitor()
        } catch {
            await fail(.watcherUnavailable)
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
        activeThemeID = nil
    }

    private func stopWatching() {
        watchHealthTask?.cancel()
        watchHealthTask = nil
        runner?.stopWatching()
    }

    private func fail(_ failure: ThemeBridgeFailure) async {
        self.failure = failure
        state = .failed
        activeThemeID = nil
        await record(failure.diagnosticCode)
    }

    private func record(_ code: DiagnosticCode) async {
        guard let diagnosticStore else { return }
        try? await diagnosticStore.record(DiagnosticEvent(
            module: .themeBridge,
            code: code,
            appVersion: appVersion
        ))
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

import AppKit
import Foundation

protocol CodexApplicationRestarting: Sendable {
    func prepareForThemedLaunch(_ bundle: VerifiedCodexBundle) async throws
    func launchNormally(bundleURL: URL) throws
}

enum ThemeBridgeCoordinatorError: Error, Equatable {
    case authorizationRequired
    case activeSessionMismatch
    case unsupportedCodexVersion(String)
    case listenerNotOwned
    case targetUnavailable
    case healthCheckFailed
    case staleSession
    case restorationFailed
}

struct ThemeBridgeApplyResult: Equatable, Sendable {
    let targetCount: Int
    let healthReport: LayoutHealthReport
}

actor ThemeBridgeCoordinator {
    private let verifier: any CodexBundleVerifying
    private let session: any ThemeSessionManaging
    private let listenerVerifier: any LoopbackListenerVerifying
    private let clientProvider: any CDPClientProviding
    private let profileStore: CompatibilityProfileStore
    private let compiler: ThemeCompiler
    private let restarter: any CodexApplicationRestarting
    private let readinessAttempts: Int
    private var maintainedTargetIDs: Set<String> = []

    init(
        verifier: any CodexBundleVerifying,
        session: any ThemeSessionManaging,
        listenerVerifier: any LoopbackListenerVerifying,
        clientProvider: any CDPClientProviding,
        profileStore: CompatibilityProfileStore,
        compiler: ThemeCompiler,
        restarter: any CodexApplicationRestarting,
        readinessAttempts: Int = 40
    ) {
        self.verifier = verifier
        self.session = session
        self.listenerVerifier = listenerVerifier
        self.clientProvider = clientProvider
        self.profileStore = profileStore
        self.compiler = compiler
        self.restarter = restarter
        self.readinessAttempts = max(1, readinessAttempts)
    }

    func apply(
        bundleURL: URL,
        theme: BridgeTheme,
        authorized: Bool,
        screenshotURL: URL?
    ) async throws -> ThemeBridgeApplyResult {
        guard authorized else { throw ThemeBridgeCoordinatorError.authorizationRequired }
        let bundle = try verifier.verify(bundleURL)
        let initialStatus = session.status()
        if case let .active(existing) = initialStatus,
           !Self.matches(existing, bundle: bundle) {
            throw ThemeBridgeCoordinatorError.activeSessionMismatch
        }
        var record: SessionRecord?
        var client: (any CDPControlling)?
        var installedTargets: [CDPTarget] = []
        do {
            switch initialStatus {
            case let .active(existing):
                record = existing
            case .inactive, .stale:
                try await restarter.prepareForThemedLaunch(bundle)
                record = try session.start(bundleURL: bundle.bundleURL, authorized: true)
            }
            guard let record else { throw ThemeBridgeCoordinatorError.restorationFailed }
            guard let profile = profileStore.profile(forVersion: record.bundleVersion) else {
                throw ThemeBridgeCoordinatorError.unsupportedCodexVersion(record.bundleVersion)
            }
            let css = try compiler.compile(theme: theme, profile: profile)
            let ready = try await waitForReadySession(record)
            client = ready.client
            let healthCheck = LayoutHealthCheck(profile: profile)
            var reports: [LayoutHealthReport] = []
            for target in ready.targets {
                try await ready.client.installStyle(css, on: target)
                installedTargets.append(target)
                let snapshot = try await ready.client.healthSnapshot(
                    on: target,
                    check: healthCheck
                )
                let report = healthCheck.evaluate(snapshot)
                reports.append(report)
                guard report.passed else {
                    throw ThemeBridgeCoordinatorError.healthCheckFailed
                }
            }
            let report = LayoutHealthReport(
                failures: reports.flatMap(\.failures)
            )
            if let screenshotURL, let target = ready.targets.first {
                let data = try await ready.client.captureScreenshot(of: target)
                try Self.writeScreenshot(data, to: screenshotURL)
            }
            return ThemeBridgeApplyResult(
                targetCount: ready.targets.count,
                healthReport: report
            )
        } catch {
            let restored = await failClose(
                bundle: bundle,
                record: record,
                client: client,
                targets: installedTargets
            )
            guard restored else { throw ThemeBridgeCoordinatorError.restorationFailed }
            throw error
        }
    }

    func restore(bundleURL: URL) async throws {
        let bundle = try verifier.verify(bundleURL)
        switch session.status() {
        case .stale:
            throw ThemeBridgeCoordinatorError.staleSession
        case .inactive:
            try restarter.launchNormally(bundleURL: bundle.bundleURL)
        case let .active(record):
            guard Self.matches(record, bundle: bundle) else {
                throw ThemeBridgeCoordinatorError.activeSessionMismatch
            }
            let client = clientProvider.client(port: record.port)
            if (try? listenerVerifier.verify(port: record.port, owner: record.process)) == true,
               let targets = try? await client.listPageTargets() {
                for target in targets {
                    try? await client.removeStyle(from: target)
                }
            }
            try session.stop()
            try restarter.launchNormally(bundleURL: bundle.bundleURL)
        }
    }

    func maintain(bundleURL: URL, theme: BridgeTheme) async throws -> Int {
        let bundle = try verifier.verify(bundleURL)
        guard case let .active(record) = session.status() else {
            throw ThemeBridgeCoordinatorError.staleSession
        }
        guard Self.matches(record, bundle: bundle) else {
            throw ThemeBridgeCoordinatorError.activeSessionMismatch
        }
        guard let profile = profileStore.profile(forVersion: record.bundleVersion) else {
            throw ThemeBridgeCoordinatorError.unsupportedCodexVersion(record.bundleVersion)
        }
        guard (try? listenerVerifier.verify(
            port: record.port,
            owner: record.process
        )) == true else {
            throw ThemeBridgeCoordinatorError.listenerNotOwned
        }
        let client = clientProvider.client(port: record.port)
        let targets = try await client.listPageTargets()
        guard !targets.isEmpty else {
            throw ThemeBridgeCoordinatorError.targetUnavailable
        }
        let activeIDs = Set(targets.map(\.id))
        maintainedTargetIDs.formIntersection(activeIDs)
        let newTargets = targets.filter { !maintainedTargetIDs.contains($0.id) }
        guard !newTargets.isEmpty else { return 0 }

        let css = try compiler.compile(theme: theme, profile: profile)
        let healthCheck = LayoutHealthCheck(profile: profile)
        for target in newTargets {
            try await client.installStyle(css, on: target)
            let report = healthCheck.evaluate(
                try await client.healthSnapshot(on: target, check: healthCheck)
            )
            guard report.passed else {
                try? await client.removeStyle(from: target)
                throw ThemeBridgeCoordinatorError.healthCheckFailed
            }
            maintainedTargetIDs.insert(target.id)
        }
        return newTargets.count
    }

    private func waitForReadySession(
        _ record: SessionRecord
    ) async throws -> (client: any CDPControlling, targets: [CDPTarget]) {
        let client = clientProvider.client(port: record.port)
        var listenerOwned = false
        for attempt in 0..<readinessAttempts {
            do {
                listenerOwned = try listenerVerifier.verify(
                    port: record.port,
                    owner: record.process
                )
                if listenerOwned {
                    let targets = try await client.listPageTargets()
                    if !targets.isEmpty { return (client, targets) }
                }
            } catch {
                listenerOwned = false
            }
            if attempt + 1 < readinessAttempts {
                try await Task.sleep(for: .milliseconds(200))
            }
        }
        throw listenerOwned
            ? ThemeBridgeCoordinatorError.targetUnavailable
            : ThemeBridgeCoordinatorError.listenerNotOwned
    }

    private func failClose(
        bundle: VerifiedCodexBundle,
        record: SessionRecord?,
        client: (any CDPControlling)?,
        targets: [CDPTarget]
    ) async -> Bool {
        if let client {
            for target in targets {
                try? await client.removeStyle(from: target)
            }
        }
        if record != nil {
            do {
                try session.stop()
            } catch {
                return false
            }
        }
        do {
            try restarter.launchNormally(bundleURL: bundle.bundleURL)
            return true
        } catch {
            return false
        }
    }

    private static func writeScreenshot(_ data: Data, to url: URL) throws {
        let fileManager = FileManager.default
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func matches(
        _ record: SessionRecord,
        bundle: VerifiedCodexBundle
    ) -> Bool {
        record.bundleIdentifier == bundle.bundleIdentifier
            && record.bundleVersion == bundle.version
            && record.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
                == bundle.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
    }
}

enum CodexRestartError: Error {
    case terminationRefused
    case terminationTimedOut
    case normalLaunchFailed
}

final class LiveCodexApplicationRestarter: CodexApplicationRestarting, @unchecked Sendable {
    func prepareForThemedLaunch(_ bundle: VerifiedCodexBundle) async throws {
        let expectedPath = bundle.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        let applications = await MainActor.run {
            NSRunningApplication.runningApplications(
                withBundleIdentifier: bundle.bundleIdentifier
            ).filter { application in
                application.bundleURL?.standardizedFileURL.resolvingSymlinksInPath()
                    == expectedPath
            }
        }
        for application in applications {
            let accepted = await MainActor.run { application.terminate() }
            guard accepted else { throw CodexRestartError.terminationRefused }
        }
        for _ in 0..<100 {
            let stillRunning = await MainActor.run {
                applications.contains { !$0.isTerminated }
            }
            if !stillRunning { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CodexRestartError.terminationTimedOut
    }

    func launchNormally(bundleURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [bundleURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CodexRestartError.normalLaunchFailed
        }
    }
}

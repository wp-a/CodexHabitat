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
    case runtimeUnavailable
    case healthCheckFailed
    case staleSession
    case restorationFailed
}

struct ThemeBridgeApplyResult: Equatable, Sendable {
    let targetCount: Int
    let healthReport: LayoutHealthReport
}

actor ThemeBridgeCoordinator {
    static let defaultReadinessAttempts = 225

    private let verifier: any CodexBundleVerifying
    private let session: any ThemeSessionManaging
    private let listenerVerifier: any LoopbackListenerVerifying
    private let clientProvider: any CDPClientProviding
    private let profileStore: CompatibilityProfileStore
    private let compiler: ThemeCompiler
    private let restarter: any CodexApplicationRestarting
    private let readinessAttempts: Int
    private var maintainedTargetIDs: Set<String> = []
    private var installingClients: [String: any CDPControlling] = [:]

    init(
        verifier: any CodexBundleVerifying,
        session: any ThemeSessionManaging,
        listenerVerifier: any LoopbackListenerVerifying,
        clientProvider: any CDPClientProviding,
        profileStore: CompatibilityProfileStore,
        compiler: ThemeCompiler,
        restarter: any CodexApplicationRestarting,
        readinessAttempts: Int = ThemeBridgeCoordinator.defaultReadinessAttempts
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
        guard let profile = profileStore.profile(forVersion: bundle.version) else {
            throw ThemeBridgeCoordinatorError.unsupportedCodexVersion(bundle.version)
        }
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
                resetMaintenanceState()
                try await restarter.prepareForThemedLaunch(bundle)
                record = try session.start(bundleURL: bundle.bundleURL, authorized: true)
            }
            guard let record else { throw ThemeBridgeCoordinatorError.restorationFailed }
            let css = try compiler.compile(theme: theme, profile: profile)
            let preflightHealthCheck = LayoutHealthCheck(
                profile: profile,
                requiresSurfaceAnnotations: false
            )
            let installedHealthCheck = LayoutHealthCheck(profile: profile)
            let ready = try await waitForReadySession(
                record,
                healthCheck: preflightHealthCheck
            )
            client = ready.client
            var reports: [LayoutHealthReport] = []
            for target in ready.targets {
                let installingClient = installingClients[target.id] ?? ready.client
                do {
                    try await installingClient.installStyle(
                        css,
                        homeMarker: profile.selectors.homeMarker,
                        annotations: HostSurfaceAnnotationPlan(profile: profile),
                        on: target
                    )
                } catch let error as CDPTargetValidationError {
                    throw error
                } catch {
                    throw ThemeBridgeCoordinatorError.runtimeUnavailable
                }
                installedTargets.append(target)
                installingClients[target.id] = installingClient
                maintainedTargetIDs.insert(target.id)
                let snapshot: LayoutHealthSnapshot
                do {
                    snapshot = try await ready.client.healthSnapshot(
                        on: target,
                        check: installedHealthCheck
                    )
                } catch let error as CDPTargetValidationError {
                    throw error
                } catch {
                    throw ThemeBridgeCoordinatorError.runtimeUnavailable
                }
                let report = installedHealthCheck.evaluate(snapshot)
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
            resetMaintenanceState()
            throw ThemeBridgeCoordinatorError.staleSession
        case .inactive:
            resetMaintenanceState()
            try restarter.launchNormally(bundleURL: bundle.bundleURL)
        case let .active(record):
            guard Self.matches(record, bundle: bundle) else {
                throw ThemeBridgeCoordinatorError.activeSessionMismatch
            }
            let client = clientProvider.client(port: record.port)
            if (try? listenerVerifier.verify(port: record.port, owner: record.process)) == true,
               let targets = try? await client.listPageTargets() {
                for target in targets {
                    let installingClient = installingClients[target.id] ?? client
                    do {
                        try await installingClient.removeStyle(from: target)
                        installingClients.removeValue(forKey: target.id)
                    } catch {}
                }
            }
            try session.stop()
            resetMaintenanceState()
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
        let targets: [CDPTarget]
        do {
            targets = try await client.listPageTargets()
        } catch let error as CDPTargetValidationError {
            throw error
        } catch {
            throw ThemeBridgeCoordinatorError.targetUnavailable
        }
        guard !targets.isEmpty else {
            throw ThemeBridgeCoordinatorError.targetUnavailable
        }
        let activeIDs = Set(targets.map(\.id))
        maintainedTargetIDs.formIntersection(activeIDs)
        installingClients = installingClients.filter { activeIDs.contains($0.key) }
        let newTargets = targets.filter { !maintainedTargetIDs.contains($0.id) }
        guard !newTargets.isEmpty else { return 0 }

        let css = try compiler.compile(theme: theme, profile: profile)
        let preflightHealthCheck = LayoutHealthCheck(
            profile: profile,
            requiresSurfaceAnnotations: false
        )
        let installedHealthCheck = LayoutHealthCheck(profile: profile)
        var installedCount = 0
        for target in newTargets {
            let isInstalled: Bool
            do {
                isInstalled = try await client.isStyleInstalled(on: target)
            } catch let error as CDPTargetValidationError {
                throw error
            } catch {
                throw ThemeBridgeCoordinatorError.runtimeUnavailable
            }
            if isInstalled {
                maintainedTargetIDs.insert(target.id)
                continue
            }
            let preflightSnapshot: LayoutHealthSnapshot
            do {
                preflightSnapshot = try await client.healthSnapshot(
                    on: target,
                    check: preflightHealthCheck
                )
            } catch let error as CDPTargetValidationError {
                throw error
            } catch {
                throw ThemeBridgeCoordinatorError.runtimeUnavailable
            }
            guard preflightHealthCheck.evaluate(preflightSnapshot).passed else {
                continue
            }
            let installingClient = installingClients[target.id] ?? client
            do {
                try await installingClient.installStyle(
                    css,
                    homeMarker: profile.selectors.homeMarker,
                    annotations: HostSurfaceAnnotationPlan(profile: profile),
                    on: target
                )
            } catch let error as CDPTargetValidationError {
                throw error
            } catch {
                throw ThemeBridgeCoordinatorError.runtimeUnavailable
            }
            installingClients[target.id] = installingClient
            let installedSnapshot: LayoutHealthSnapshot
            do {
                installedSnapshot = try await client.healthSnapshot(
                    on: target,
                    check: installedHealthCheck
                )
            } catch let error as CDPTargetValidationError {
                throw error
            } catch {
                throw ThemeBridgeCoordinatorError.runtimeUnavailable
            }
            let report = installedHealthCheck.evaluate(installedSnapshot)
            guard report.passed else {
                do {
                    try await installingClient.removeStyle(from: target)
                    installingClients.removeValue(forKey: target.id)
                } catch {}
                throw ThemeBridgeCoordinatorError.healthCheckFailed
            }
            maintainedTargetIDs.insert(target.id)
            installedCount += 1
        }
        return installedCount
    }

    private func waitForReadySession(
        _ record: SessionRecord,
        healthCheck: LayoutHealthCheck
    ) async throws -> (client: any CDPControlling, targets: [CDPTarget]) {
        let client = clientProvider.client(port: record.port)
        var sawOwnedListener = false
        var sawMainTarget = false
        var sawRuntimeFailure = false
        var sawDecodedUnhealthySnapshot = false
        for attempt in 0..<readinessAttempts {
            do {
                guard try listenerVerifier.verify(
                    port: record.port,
                    owner: record.process
                ) else {
                    continue
                }
                sawOwnedListener = true
                let targets: [CDPTarget]
                do {
                    targets = try await client.listPageTargets()
                } catch let error as CDPTargetValidationError {
                    throw error
                } catch {
                    continue
                }
                if !targets.isEmpty {
                    sawMainTarget = true
                    var healthyTargets: [CDPTarget] = []
                    for target in targets {
                        do {
                            let snapshot = try await client.healthSnapshot(
                                on: target,
                                check: healthCheck
                            )
                            if healthCheck.evaluate(snapshot).passed {
                                healthyTargets.append(target)
                            } else {
                                sawDecodedUnhealthySnapshot = true
                            }
                        } catch let error as CDPTargetValidationError {
                            throw error
                        } catch {
                            sawRuntimeFailure = true
                        }
                    }
                    if !healthyTargets.isEmpty {
                        return (client, healthyTargets)
                    }
                }
            } catch let error as CDPTargetValidationError {
                throw error
            } catch {}
            if attempt + 1 < readinessAttempts {
                try await Task.sleep(for: .milliseconds(200))
            }
        }
        if sawDecodedUnhealthySnapshot {
            throw ThemeBridgeCoordinatorError.healthCheckFailed
        }
        if sawMainTarget, sawRuntimeFailure {
            throw ThemeBridgeCoordinatorError.runtimeUnavailable
        }
        if sawOwnedListener {
            throw ThemeBridgeCoordinatorError.targetUnavailable
        }
        throw ThemeBridgeCoordinatorError.listenerNotOwned
    }

    private func failClose(
        bundle: VerifiedCodexBundle,
        record: SessionRecord?,
        client: (any CDPControlling)?,
        targets: [CDPTarget]
    ) async -> Bool {
        if let client {
            for target in targets {
                let installingClient = installingClients[target.id] ?? client
                do {
                    try await installingClient.removeStyle(from: target)
                    installingClients.removeValue(forKey: target.id)
                } catch {}
            }
        }
        if record != nil {
            do {
                try session.stop()
                resetMaintenanceState()
            } catch {
                return false
            }
        } else {
            resetMaintenanceState()
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

    private func resetMaintenanceState() {
        maintainedTargetIDs.removeAll()
        installingClients.removeAll()
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

@MainActor
protocol RunningCodexApplication: AnyObject, Sendable {
    var bundleURL: URL? { get }
    var isTerminated: Bool { get }
    func terminate() -> Bool
    func forceTerminate() -> Bool
}

@MainActor
private final class LiveRunningCodexApplication: RunningCodexApplication, @unchecked Sendable {
    private let application: NSRunningApplication

    init(_ application: NSRunningApplication) {
        self.application = application
    }

    var bundleURL: URL? { application.bundleURL }
    var isTerminated: Bool { application.isTerminated }
    func terminate() -> Bool { application.terminate() }
    func forceTerminate() -> Bool { application.forceTerminate() }
}

final class LiveCodexApplicationRestarter: CodexApplicationRestarting, @unchecked Sendable {
    typealias ApplicationProvider = @MainActor @Sendable (String) -> [any RunningCodexApplication]
    typealias Pause = @Sendable () async throws -> Void

    private let applicationProvider: ApplicationProvider
    private let pause: Pause
    private let gracefulAttempts: Int
    private let forcedAttempts: Int

    init(
        applicationProvider: @escaping ApplicationProvider = { bundleIdentifier in
            NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).map(LiveRunningCodexApplication.init)
        },
        pause: @escaping Pause = {
            try await Task.sleep(for: .milliseconds(100))
        },
        gracefulAttempts: Int = 50,
        forcedAttempts: Int = 50
    ) {
        self.applicationProvider = applicationProvider
        self.pause = pause
        self.gracefulAttempts = max(1, gracefulAttempts)
        self.forcedAttempts = max(1, forcedAttempts)
    }

    func prepareForThemedLaunch(_ bundle: VerifiedCodexBundle) async throws {
        let expectedPath = bundle.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidates = await applicationProvider(bundle.bundleIdentifier)
        let applications = await MainActor.run {
            candidates.filter { application in
                application.bundleURL?.standardizedFileURL.resolvingSymlinksInPath()
                    == expectedPath
            }
        }
        for application in applications {
            _ = await MainActor.run { application.terminate() }
        }
        if try await waitForTermination(applications, attempts: gracefulAttempts) {
            return
        }
        let remaining = await MainActor.run {
            applications.filter { !$0.isTerminated }
        }
        for application in remaining {
            let accepted = await MainActor.run { application.forceTerminate() }
            guard accepted else { throw CodexRestartError.terminationRefused }
        }
        if try await waitForTermination(applications, attempts: forcedAttempts) {
            return
        }
        throw CodexRestartError.terminationTimedOut
    }

    private func waitForTermination(
        _ applications: [any RunningCodexApplication],
        attempts: Int
    ) async throws -> Bool {
        for _ in 0..<attempts {
            if await MainActor.run(body: { applications.allSatisfy(\.isTerminated) }) {
                return true
            }
            try await pause()
        }
        return await MainActor.run {
            applications.allSatisfy(\.isTerminated)
        }
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

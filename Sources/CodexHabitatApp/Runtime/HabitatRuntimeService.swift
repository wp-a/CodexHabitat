import CodexConnector
import Combine
import Foundation
import HabitatCore

protocol CodexRuntimeClient: Sendable {
    func connect() async throws
    func subscribeToLoadedThreads() async throws -> Int
    func readLoadedThreadStatuses() async throws -> [SanitizedThreadStatus]
    func readRateLimits() async throws -> CodexRateLimitUpdate?
    func receiveNextEvent() async throws -> CodexReadEvent
    func disconnect() async
}

extension CodexControlClient: CodexRuntimeClient {}

protocol CodexTokenMetricsMonitoring: Sendable {
    func sample(at date: Date) async -> TokenMetricsSummary?
    func selectThread(idHash: String?) async
}

extension CodexTokenMetricsMonitoring {
    func selectThread(idHash _: String?) async {}
}

extension SessionTokenMetricsMonitor: CodexTokenMetricsMonitoring {}

protocol HabitatRuntimeClock: Sendable {
    func sleep(for duration: Duration) async throws
}

struct SystemHabitatRuntimeClock: HabitatRuntimeClock {
    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}

enum HabitatRuntimeAction: Equatable, Sendable {
    case activity(AgentActivity, threadIDHash: String?, timestamp: Date)
    case completed(threadIDHash: String?, timestamp: Date)
    case rateLimits(primary: RateLimitSummary?, secondary: RateLimitSummary?)
    case ignore
}

enum HabitatRuntimeEventMapper {
    static func initialActivity(
        for statuses: [SanitizedThreadStatus]
    ) -> AgentActivity {
        if statuses.contains(.active) { return .working }
        if statuses.contains(.systemError) { return .failed }
        return .resting
    }

    static func action(for event: CodexReadEvent) -> HabitatRuntimeAction {
        switch event.category {
        case .threadStarted, .turnStarted:
            return .activity(
                .working,
                threadIDHash: event.threadIDHash,
                timestamp: event.timestamp
            )
        case .threadStatusChanged:
            guard let status = event.status else { return .ignore }
            return .activity(
                activity(for: status),
                threadIDHash: event.threadIDHash,
                timestamp: event.timestamp
            )
        case .turnCompleted:
            return .completed(
                threadIDHash: event.threadIDHash,
                timestamp: event.timestamp
            )
        case .attentionRequired:
            return .activity(
                .attention,
                threadIDHash: event.threadIDHash,
                timestamp: event.timestamp
            )
        case .error:
            return .activity(
                .failed,
                threadIDHash: event.threadIDHash,
                timestamp: event.timestamp
            )
        case .rateLimitsUpdated:
            guard let limits = event.rateLimits else { return .ignore }
            return .rateLimits(
                primary: summary(
                    usedPercent: limits.primaryUsedPercent,
                    resetAt: limits.primaryResetAt
                ),
                secondary: summary(
                    usedPercent: limits.secondaryUsedPercent,
                    resetAt: limits.secondaryResetAt
                )
            )
        }
    }

    static func rateLimitAction(_ limits: CodexRateLimitUpdate) -> HabitatRuntimeAction {
        .rateLimits(
            primary: summary(
                usedPercent: limits.primaryUsedPercent,
                resetAt: limits.primaryResetAt
            ),
            secondary: summary(
                usedPercent: limits.secondaryUsedPercent,
                resetAt: limits.secondaryResetAt
            )
        )
    }

    private static func activity(for status: SanitizedThreadStatus) -> AgentActivity {
        switch status {
        case .active:
            .working
        case .idle, .notLoaded:
            .resting
        case .systemError:
            .failed
        }
    }

    private static func summary(
        usedPercent: Double?,
        resetAt: Date?
    ) -> RateLimitSummary? {
        guard usedPercent != nil || resetAt != nil else { return nil }
        return RateLimitSummary(usedPercent: usedPercent, resetAt: resetAt)
    }
}

actor HabitatRuntimeService {
    typealias ClientFactory = @Sendable () throws -> any CodexRuntimeClient

    private let state: HabitatState
    private let clientFactory: ClientFactory
    private let reconnectClock: any HabitatRuntimeClock
    private let reconnectPolicy: ReconnectPolicy
    private let fallbackMonitor: SessionMetadataMonitor?
    private let metricsMonitor: (any CodexTokenMetricsMonitoring)?
    private var loopTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?
    private var metricsTask: Task<Void, Never>?
    private var currentClient: (any CodexRuntimeClient)?
    private var primaryOnline = false
    private var monitoringActive = true

    init(
        state: HabitatState = HabitatState(),
        clientFactory: @escaping ClientFactory,
        reconnectClock: any HabitatRuntimeClock = SystemHabitatRuntimeClock(),
        reconnectPolicy: ReconnectPolicy = ReconnectPolicy(),
        fallbackMonitor: SessionMetadataMonitor? = nil,
        metricsMonitor: (any CodexTokenMetricsMonitoring)? = nil
    ) {
        self.state = state
        self.clientFactory = clientFactory
        self.reconnectClock = reconnectClock
        self.reconnectPolicy = reconnectPolicy
        self.fallbackMonitor = fallbackMonitor
        self.metricsMonitor = metricsMonitor
    }

    static func live(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> HabitatRuntimeService {
        let root = applicationSupportRoot(fileManager: fileManager, environment: environment)
        let privateRoot = root.appending(path: "Private", directoryHint: .isDirectory)
        let initialSalt = try? EventHashSaltStore(
            root: privateRoot,
            fileManager: fileManager
        ).loadOrCreate()
        let threadIDHasher: (@Sendable (String) -> String)?
        if let initialSalt {
            let sanitizer = CodexEventSanitizer(salt: initialSalt)
            threadIDHasher = { sanitizer.hashThreadID($0) }
        } else {
            threadIDHasher = nil
        }
        return HabitatRuntimeService(clientFactory: {
            let salt = try EventHashSaltStore(
                root: privateRoot,
                fileManager: .default
            ).loadOrCreate()
            return CodexControlClient(
                transport: ProcessTransport(),
                sanitizer: CodexEventSanitizer(salt: salt)
            )
        }, fallbackMonitor: .live(environment: environment),
           metricsMonitor: SessionTokenMetricsMonitor.live(
            environment: environment,
            threadIDHasher: threadIDHasher
           ))
    }

    func start() {
        guard loopTask == nil else { return }
        if monitoringActive {
            startFallbackMonitor()
            startMetricsMonitor()
        }
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() async {
        guard let task = loopTask else {
            await publishOffline()
            return
        }
        loopTask = nil
        task.cancel()
        fallbackTask?.cancel()
        let fallbackTask = fallbackTask
        self.fallbackTask = nil
        metricsTask?.cancel()
        let metricsTask = metricsTask
        self.metricsTask = nil
        if let currentClient {
            await currentClient.disconnect()
        }
        await task.value
        await fallbackTask?.value
        await metricsTask?.value
        currentClient = nil
        primaryOnline = false
        await publishOffline()
    }

    func snapshots() async -> AsyncStream<HabitatSnapshot> {
        await state.snapshots()
    }

    func setMonitoringActive(_ active: Bool) async {
        guard monitoringActive != active else { return }
        monitoringActive = active
        if active {
            guard loopTask != nil else { return }
            startFallbackMonitor()
            startMetricsMonitor()
            return
        }
        fallbackTask?.cancel()
        let fallbackTask = fallbackTask
        self.fallbackTask = nil
        metricsTask?.cancel()
        let metricsTask = metricsTask
        self.metricsTask = nil
        await fallbackTask?.value
        await metricsTask?.value
    }

    func currentSnapshot() async -> HabitatSnapshot {
        await state.currentSnapshot()
    }

    private func runLoop() async {
        var policy = reconnectPolicy
        await state.setConnectionHealth(
            fallbackMonitor == nil ? .reconnecting : .estimated
        )

        while !Task.isCancelled {
            let client: any CodexRuntimeClient
            do {
                client = try clientFactory()
                currentClient = client
                try await client.connect()
                guard !Task.isCancelled else { break }
                _ = try await client.subscribeToLoadedThreads()
                let statuses = try await client.readLoadedThreadStatuses()
                if let limits = try? await client.readRateLimits() {
                    await apply(HabitatRuntimeEventMapper.rateLimitAction(limits))
                }
                policy.reset()
                primaryOnline = true
                await state.setConnectionHealth(.online)
                await state.update(
                    activity: HabitatRuntimeEventMapper.initialActivity(for: statuses),
                    threadIDHash: nil,
                    eventTimestamp: nil
                )

                while !Task.isCancelled {
                    let event = try await client.receiveNextEvent()
                    await apply(HabitatRuntimeEventMapper.action(for: event))
                }
            } catch {
                primaryOnline = false
                if !Task.isCancelled {
                    await currentClient?.disconnect()
                }
                currentClient = nil
                guard !Task.isCancelled else { break }
                await state.setConnectionHealth(
                    fallbackMonitor == nil ? .reconnecting : .estimated
                )
                if fallbackMonitor == nil {
                    await state.update(
                        activity: .offline,
                        threadIDHash: nil,
                        eventTimestamp: nil
                    )
                }
                let delay = policy.nextDelay()
                do {
                    try await reconnectClock.sleep(for: .seconds(delay))
                } catch {
                    break
                }
            }
        }
    }

    private func apply(_ action: HabitatRuntimeAction) async {
        switch action {
        case let .activity(activity, threadIDHash, timestamp):
            await metricsMonitor?.selectThread(idHash: threadIDHash)
            await state.update(
                activity: activity,
                threadIDHash: threadIDHash,
                eventTimestamp: timestamp
            )
            if activity == .working {
                nudgeMetricsMonitor()
            }
        case let .completed(threadIDHash, timestamp):
            await metricsMonitor?.selectThread(idHash: threadIDHash)
            Task {
                await state.markCompleted(
                    threadIDHash: threadIDHash,
                    eventTimestamp: timestamp,
                    successDuration: .seconds(2)
                )
            }
        case let .rateLimits(primary, secondary):
            await state.setRateLimits(primary: primary, secondary: secondary)
        case .ignore:
            break
        }
    }

    private func startFallbackMonitor() {
        guard fallbackTask == nil, let fallbackMonitor else { return }
        fallbackTask = Task { [weak self] in
            // The first offline sample only rebuilds the on-disk baseline, so
            // its diff against a stale fingerprint set is discarded.
            var needsBaseline = true
            while !Task.isCancelled {
                if let self {
                    if await self.primaryOnline {
                        needsBaseline = true
                    } else {
                        let activity = await fallbackMonitor.sample()
                        if needsBaseline {
                            needsBaseline = false
                        } else {
                            await self.applyFallback(activity)
                        }
                    }
                }
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    return
                }
            }
        }
    }

    private func startMetricsMonitor() {
        guard metricsTask == nil, let metricsMonitor else { return }
        metricsTask = Task { [weak self] in
            while !Task.isCancelled {
                let metrics = await metricsMonitor.sample(at: Date())
                guard let self else { return }
                await self.state.setTokenMetrics(metrics)
                let activity = await self.state.currentSnapshot().activity
                let interval: Duration = switch activity {
                case .working, .attention:
                    .seconds(1)
                case .resting, .succeeded, .failed, .offline:
                    .seconds(5)
                }
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
            }
        }
    }

    private func nudgeMetricsMonitor() {
        guard monitoringActive, metricsTask != nil else { return }
        metricsTask?.cancel()
        metricsTask = nil
        startMetricsMonitor()
    }

    private func applyFallback(_ activity: SessionMetadataActivity?) async {
        guard !primaryOnline, let activity else { return }
        await state.setConnectionHealth(.estimated)
        let currentActivity = await state.currentSnapshot().activity
        switch activity {
        case .resting:
            guard currentActivity != .resting else { return }
            await state.update(
                activity: .resting,
                threadIDHash: nil,
                eventTimestamp: nil
            )
        case .working:
            guard currentActivity != .working else { return }
            await state.update(
                activity: .working,
                threadIDHash: nil,
                eventTimestamp: Date()
            )
            nudgeMetricsMonitor()
        case .completed:
            Task {
                await state.markCompleted(
                    threadIDHash: nil,
                    eventTimestamp: Date(),
                    successDuration: .seconds(2)
                )
            }
        }
    }

    private func publishOffline() async {
        await state.setConnectionHealth(.offline)
        await state.update(
            activity: .offline,
            threadIDHash: nil,
            eventTimestamp: nil
        )
    }

    private static func applicationSupportRoot(
        fileManager: FileManager,
        environment: [String: String]
    ) -> URL {
        if let configured = environment["CODEX_HABITAT_HOME"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
        }
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser.appending(
            path: "Library/Application Support",
            directoryHint: .isDirectory
        )
        return applicationSupport.appending(
            path: "Codex Habitat",
            directoryHint: .isDirectory
        )
    }
}

@MainActor
final class HabitatRuntimeController {
    private let service: HabitatRuntimeService
    private var snapshotTask: Task<Void, Never>?
    private var visibilityCancellable: AnyCancellable?

    init(service: HabitatRuntimeService) {
        self.service = service
    }

    static func live() -> HabitatRuntimeController {
        HabitatRuntimeController(service: .live())
    }

    func start(desktopController: HabitatDesktopController) {
        guard snapshotTask == nil else { return }
        visibilityCancellable = desktopController.$isVisible
            .removeDuplicates()
            .sink { [service] isVisible in
                Task { await service.setMonitoringActive(isVisible) }
            }
        snapshotTask = Task { [weak desktopController, service] in
            await service.setMonitoringActive(desktopController?.isVisible ?? false)
            let stream = await service.snapshots()
            await service.start()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                desktopController?.apply(snapshot: snapshot)
            }
        }
    }

    func stop() async {
        visibilityCancellable?.cancel()
        visibilityCancellable = nil
        snapshotTask?.cancel()
        snapshotTask = nil
        await service.stop()
    }
}

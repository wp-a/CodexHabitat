import CodexConnector
import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test
func runtimeEventMapperUsesOnlySanitizedEventFields() {
    let timestamp = Date(timeIntervalSince1970: 300)

    #expect(HabitatRuntimeEventMapper.action(for: CodexReadEvent(
        category: .turnStarted,
        threadIDHash: "hash",
        status: nil,
        timestamp: timestamp
    )) == .activity(.working, threadIDHash: "hash", timestamp: timestamp))
    #expect(HabitatRuntimeEventMapper.action(for: CodexReadEvent(
        category: .attentionRequired,
        threadIDHash: "hash",
        status: nil,
        timestamp: timestamp
    )) == .activity(.attention, threadIDHash: "hash", timestamp: timestamp))
    #expect(HabitatRuntimeEventMapper.action(for: CodexReadEvent(
        category: .threadStatusChanged,
        threadIDHash: "hash",
        status: .systemError,
        timestamp: timestamp
    )) == .activity(.failed, threadIDHash: "hash", timestamp: timestamp))
    #expect(HabitatRuntimeEventMapper.action(for: CodexReadEvent(
        category: .turnCompleted,
        threadIDHash: "hash",
        status: nil,
        timestamp: timestamp
    )) == .completed(threadIDHash: "hash", timestamp: timestamp))
    #expect(HabitatRuntimeEventMapper.initialActivity(for: [.idle, .active]) == .working)
    #expect(HabitatRuntimeEventMapper.initialActivity(for: [.systemError, .idle]) == .failed)
    #expect(HabitatRuntimeEventMapper.initialActivity(for: []) == .resting)
}

@Test
func runtimeConnectsPublishesEventsAndStopsOffline() async {
    let timestamp = Date(timeIntervalSince1970: 350)
    let client = FakeCodexRuntimeClient(
        rateLimits: CodexRateLimitUpdate(
            primaryUsedPercent: 28,
            primaryResetAt: nil,
            secondaryUsedPercent: nil,
            secondaryResetAt: nil
        ),
        events: [CodexReadEvent(
            category: .turnStarted,
            threadIDHash: "safe-hash",
            status: nil,
            timestamp: timestamp
        )]
    )
    let service = HabitatRuntimeService(
        clientFactory: { client },
        reconnectClock: BlockingRuntimeClock()
    )

    await service.start()
    let connected = await eventually {
        let snapshot = await service.currentSnapshot()
        return snapshot.activity == .working
            && snapshot.connectionHealth == .online
            && snapshot.primaryRateLimit?.usedPercent == 28
    }
    #expect(connected)

    await service.stop()
    let stopped = await service.currentSnapshot()
    #expect(stopped.activity == .offline)
    #expect(stopped.connectionHealth == .offline)
    #expect(await client.disconnectCount == 1)
}

private actor FakeCodexRuntimeClient: CodexRuntimeClient {
    let rateLimits: CodexRateLimitUpdate?
    var events: [CodexReadEvent]
    var waiter: CheckedContinuation<CodexReadEvent, any Error>?
    private(set) var disconnectCount = 0

    init(rateLimits: CodexRateLimitUpdate?, events: [CodexReadEvent]) {
        self.rateLimits = rateLimits
        self.events = events
    }

    func connect() async throws {}
    func subscribeToLoadedThreads() async throws -> Int { 1 }
    func readLoadedThreadStatuses() async throws -> [SanitizedThreadStatus] { [.idle] }
    func readRateLimits() async throws -> CodexRateLimitUpdate? { rateLimits }

    func receiveNextEvent() async throws -> CodexReadEvent {
        if !events.isEmpty {
            return events.removeFirst()
        }
        return try await withCheckedThrowingContinuation { waiter = $0 }
    }

    func disconnect() async {
        disconnectCount += 1
        waiter?.resume(throwing: CodexControlClientError.transportClosed)
        waiter = nil
    }
}

private actor BlockingRuntimeClock: HabitatRuntimeClock {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: .seconds(60))
    }
}

private func eventually(
    _ predicate: @escaping @Sendable () async -> Bool
) async -> Bool {
    for _ in 0..<1_000 {
        if await predicate() { return true }
        await Task.yield()
    }
    return false
}

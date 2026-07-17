import Foundation
import Testing
@testable import HabitatCore

@Test
func codexStatusesMapToPublicActivity() {
    #expect(AgentActivity.codexStatus(.active) == .working)
    #expect(AgentActivity.codexStatus(.idle) == .resting)
    #expect(AgentActivity.codexStatus(.systemError) == .failed)
    #expect(AgentActivity.codexStatus(.notLoaded) == .resting)
}

@Test
func statePublishesSanitizedSnapshots() async {
    let state = HabitatState()
    let timestamp = Date(timeIntervalSince1970: 100)

    await state.update(
        activity: .working,
        threadIDHash: "local-hash",
        eventTimestamp: timestamp
    )

    let snapshot = await state.currentSnapshot()
    #expect(snapshot.activity == .working)
    #expect(snapshot.threadIDHash == "local-hash")
    #expect(snapshot.eventTimestamp == timestamp)
    #expect(snapshot.connectionHealth == .offline)
}

@Test
func snapshotsYieldInitialAndUpdatedValues() async {
    let initial = HabitatSnapshot(activity: .resting)
    let state = HabitatState(initialSnapshot: initial)
    let stream = await state.snapshots()
    var iterator = stream.makeAsyncIterator()

    #expect(await iterator.next() == initial)

    await state.update(
        activity: .working,
        threadIDHash: "local-hash",
        eventTimestamp: Date(timeIntervalSince1970: 150)
    )

    #expect(await iterator.next()?.activity == .working)
}

@Test
func connectionAndRateLimitUpdatesPreserveActivityMetadata() async {
    let timestamp = Date(timeIntervalSince1970: 175)
    let state = HabitatState(initialSnapshot: HabitatSnapshot(
        activity: .working,
        threadIDHash: "local-hash",
        eventTimestamp: timestamp
    ))
    let primary = RateLimitSummary(usedPercent: 42, resetAt: nil)
    let secondary = RateLimitSummary(
        usedPercent: 7,
        resetAt: Date(timeIntervalSince1970: 300)
    )

    await state.setConnectionHealth(.online)
    await state.setRateLimits(primary: primary, secondary: secondary)

    let snapshot = await state.currentSnapshot()
    #expect(snapshot.activity == .working)
    #expect(snapshot.threadIDHash == "local-hash")
    #expect(snapshot.eventTimestamp == timestamp)
    #expect(snapshot.connectionHealth == .online)
    #expect(snapshot.primaryRateLimit == primary)
    #expect(snapshot.secondaryRateLimit == secondary)
}

@Test
func tokenMetricUpdatesPreserveTheRestOfTheSnapshot() async {
    let metrics = TokenMetricsSummary(
        inputTokens: 1_000,
        cachedInputTokens: 600,
        outputTokens: 100,
        reasoningOutputTokens: 20,
        totalTokens: 1_100,
        lastInputTokens: 500,
        lastOutputTokens: 40,
        modelContextWindow: 1_000,
        recentOutputTokens: 40,
        updatedAt: Date(timeIntervalSince1970: 200)
    )
    let state = HabitatState(initialSnapshot: HabitatSnapshot(
        activity: .working,
        connectionHealth: .estimated,
        primaryRateLimit: RateLimitSummary(usedPercent: 42, resetAt: nil)
    ))

    await state.setTokenMetrics(metrics)
    await state.setConnectionHealth(.online)

    let snapshot = await state.currentSnapshot()
    #expect(snapshot.tokenMetrics == metrics)
    #expect(snapshot.activity == .working)
    #expect(snapshot.connectionHealth == .online)
    #expect(snapshot.primaryRateLimit?.usedPercent == 42)
}

@Test
func completedStateReturnsToRestingAfterClockAdvances() async {
    let clock = ManualHabitatClock()
    let state = HabitatState(clock: clock)

    let transition = Task {
        await state.markCompleted(
            threadIDHash: "local-hash",
            eventTimestamp: Date(timeIntervalSince1970: 200),
            successDuration: .seconds(2)
        )
    }

    while await !clock.isSleeping {
        await Task.yield()
    }

    #expect(await state.currentSnapshot().activity == .succeeded)

    await clock.advance()
    await transition.value

    #expect(await state.currentSnapshot().activity == .resting)
}

private actor ManualHabitatClock: HabitatClock {
    private var continuation: CheckedContinuation<Void, Never>?

    var isSleeping: Bool {
        continuation != nil
    }

    func sleep(for duration: Duration) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func advance() {
        continuation?.resume()
        continuation = nil
    }
}

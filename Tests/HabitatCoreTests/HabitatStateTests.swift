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

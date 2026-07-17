import Foundation

public protocol HabitatClock: Sendable {
    func sleep(for duration: Duration) async
}

public struct SystemHabitatClock: HabitatClock {
    public init() {}

    public func sleep(for duration: Duration) async {
        try? await ContinuousClock().sleep(for: duration)
    }
}

public actor HabitatState {
    private let clock: any HabitatClock
    private var snapshot: HabitatSnapshot
    private var completionGeneration = 0
    private var subscribers: [UUID: AsyncStream<HabitatSnapshot>.Continuation] = [:]

    public init(
        initialSnapshot: HabitatSnapshot = HabitatSnapshot(),
        clock: any HabitatClock = SystemHabitatClock()
    ) {
        snapshot = initialSnapshot
        self.clock = clock
    }

    public func currentSnapshot() -> HabitatSnapshot {
        snapshot
    }

    public func snapshots() -> AsyncStream<HabitatSnapshot> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: HabitatSnapshot.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        subscribers[id] = continuation
        continuation.yield(snapshot)
        return stream
    }

    public func update(
        activity: AgentActivity,
        threadIDHash: String?,
        eventTimestamp: Date?
    ) {
        completionGeneration += 1
        publish(
            HabitatSnapshot(
                activity: activity,
                threadIDHash: threadIDHash,
                eventTimestamp: eventTimestamp,
                connectionHealth: snapshot.connectionHealth,
                primaryRateLimit: snapshot.primaryRateLimit,
                secondaryRateLimit: snapshot.secondaryRateLimit,
                timer: snapshot.timer
            )
        )
    }

    public func setConnectionHealth(_ connectionHealth: ConnectionHealth) {
        publish(
            HabitatSnapshot(
                activity: snapshot.activity,
                threadIDHash: snapshot.threadIDHash,
                eventTimestamp: snapshot.eventTimestamp,
                connectionHealth: connectionHealth,
                primaryRateLimit: snapshot.primaryRateLimit,
                secondaryRateLimit: snapshot.secondaryRateLimit,
                timer: snapshot.timer
            )
        )
    }

    public func setRateLimits(
        primary: RateLimitSummary?,
        secondary: RateLimitSummary?
    ) {
        publish(
            HabitatSnapshot(
                activity: snapshot.activity,
                threadIDHash: snapshot.threadIDHash,
                eventTimestamp: snapshot.eventTimestamp,
                connectionHealth: snapshot.connectionHealth,
                primaryRateLimit: primary,
                secondaryRateLimit: secondary,
                timer: snapshot.timer
            )
        )
    }

    public func markCompleted(
        threadIDHash: String?,
        eventTimestamp: Date?,
        successDuration: Duration
    ) async {
        completionGeneration += 1
        let generation = completionGeneration
        publish(
            HabitatSnapshot(
                activity: .succeeded,
                threadIDHash: threadIDHash,
                eventTimestamp: eventTimestamp,
                connectionHealth: snapshot.connectionHealth,
                primaryRateLimit: snapshot.primaryRateLimit,
                secondaryRateLimit: snapshot.secondaryRateLimit,
                timer: snapshot.timer
            )
        )

        await clock.sleep(for: successDuration)

        guard generation == completionGeneration, snapshot.activity == .succeeded else {
            return
        }
        publish(
            HabitatSnapshot(
                activity: .resting,
                threadIDHash: threadIDHash,
                eventTimestamp: eventTimestamp,
                connectionHealth: snapshot.connectionHealth,
                primaryRateLimit: snapshot.primaryRateLimit,
                secondaryRateLimit: snapshot.secondaryRateLimit,
                timer: snapshot.timer
            )
        )
    }

    private func publish(_ nextSnapshot: HabitatSnapshot) {
        guard nextSnapshot != snapshot else { return }
        snapshot = nextSnapshot
        for continuation in subscribers.values {
            continuation.yield(nextSnapshot)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }
}

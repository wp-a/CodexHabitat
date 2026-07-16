import HabitatCore

public struct PetAnimator {
    private let clock: any AnimationClock
    private let availableRows: Set<Int>
    private var activity: AgentActivity
    private var animation: PetAnimation
    private var startedAtMilliseconds: UInt64
    private var successAnimationCompleted = false
    public var reduceMotion: Bool

    public init(
        clock: any AnimationClock = SystemAnimationClock(),
        initialActivity: AgentActivity = .resting,
        availableRows: Set<Int> = Set(0..<9),
        reduceMotion: Bool = false
    ) {
        self.clock = clock
        self.availableRows = availableRows
        activity = initialActivity
        animation = Self.resolvedAnimation(
            Self.animation(for: initialActivity),
            availableRows: availableRows
        )
        startedAtMilliseconds = clock.nowMilliseconds()
        self.reduceMotion = reduceMotion
    }

    public mutating func update(activity newActivity: AgentActivity) -> PetFrame {
        if newActivity != activity {
            activity = newActivity
            animation = Self.resolvedAnimation(
                Self.animation(for: newActivity),
                availableRows: availableRows
            )
            startedAtMilliseconds = clock.nowMilliseconds()
            successAnimationCompleted = false
        }
        return currentFrame()
    }

    public mutating func transition(to requestedAnimation: PetAnimation) -> PetFrame {
        animation = Self.resolvedAnimation(requestedAnimation, availableRows: availableRows)
        startedAtMilliseconds = clock.nowMilliseconds()
        successAnimationCompleted = false
        return currentFrame()
    }

    public mutating func currentFrame() -> PetFrame {
        if reduceMotion {
            return Self.stableIdleFrame
        }
        let now = clock.nowMilliseconds()
        let elapsed = now >= startedAtMilliseconds ? now - startedAtMilliseconds : 0

        if activity == .succeeded,
           animation == .review,
           !successAnimationCompleted,
           elapsed >= animation.totalDurationMilliseconds {
            animation = .idle
            startedAtMilliseconds = now
            successAnimationCompleted = true
            return Self.stableIdleFrame
        }

        return PetFrame(
            animation: animation,
            row: animation.rowIndex,
            column: animation.frameColumn(elapsedMilliseconds: elapsed)
        )
    }

    private static let stableIdleFrame = PetFrame(animation: .idle, row: 0, column: 0)

    private static func resolvedAnimation(
        _ requested: PetAnimation,
        availableRows: Set<Int>
    ) -> PetAnimation {
        availableRows.contains(requested.rowIndex) ? requested : .idle
    }

    private static func animation(for activity: AgentActivity) -> PetAnimation {
        switch activity {
        case .resting, .offline:
            .idle
        case .working:
            .running
        case .attention:
            .waiting
        case .succeeded:
            .review
        case .failed:
            .failed
        }
    }
}

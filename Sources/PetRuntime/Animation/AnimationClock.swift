import Foundation

public protocol AnimationClock: Sendable {
    func nowMilliseconds() -> UInt64
}

public struct SystemAnimationClock: AnimationClock {
    public init() {}

    public func nowMilliseconds() -> UInt64 {
        UInt64(ProcessInfo.processInfo.systemUptime * 1_000)
    }
}

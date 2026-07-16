import Foundation

public struct ClockWidgetConfiguration: Equatable, Sendable {
    public var uses24HourClock: Bool

    public init(uses24HourClock: Bool = false) {
        self.uses24HourClock = uses24HourClock
    }
}

public enum ClockWidget {
    public static func metric(now: Date?) -> MetricValue {
        guard let now else { return .unavailable }
        return .date(now)
    }
}

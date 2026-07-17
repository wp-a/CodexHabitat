import HabitatCore

public struct SpeedWidgetConfiguration: Equatable, Sendable {
    public init() {}
}

public enum SpeedWidget {
    public static func metric(snapshot: HabitatSnapshot?) -> MetricValue {
        guard let value = snapshot?.tokenMetrics?.outputTokensPerMinute,
              value.isFinite,
              value >= 0
        else {
            return .unavailable
        }
        return .tokensPerMinute(value)
    }
}

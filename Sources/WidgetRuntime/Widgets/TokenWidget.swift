import HabitatCore

public struct TokenWidgetConfiguration: Equatable, Sendable {
    public init() {}
}

public enum TokenWidget {
    public static func metric(snapshot: HabitatSnapshot?) -> MetricValue {
        guard let value = snapshot?.tokenMetrics?.totalTokens else { return .unavailable }
        return .tokenCount(max(0, value))
    }
}

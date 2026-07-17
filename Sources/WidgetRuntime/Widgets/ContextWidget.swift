import HabitatCore

public struct ContextWidgetConfiguration: Equatable, Sendable {
    public init() {}
}

public enum ContextWidget {
    public static func metric(snapshot: HabitatSnapshot?) -> MetricValue {
        guard let value = snapshot?.tokenMetrics?.contextUsedPercent else { return .unavailable }
        return .percentage(min(max(value, 0), 100))
    }
}

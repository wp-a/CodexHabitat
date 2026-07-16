import HabitatCore

public struct StatusWidgetConfiguration: Equatable, Sendable {
    public var showsConnectionHealth: Bool

    public init(showsConnectionHealth: Bool = true) {
        self.showsConnectionHealth = showsConnectionHealth
    }
}

public enum StatusWidget {
    public static func metric(snapshot: HabitatSnapshot?) -> MetricValue {
        guard let snapshot else { return .unavailable }
        return .activity(snapshot.activity)
    }
}

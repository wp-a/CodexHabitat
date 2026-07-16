import HabitatCore

public enum UsageBucket: String, Codable, Equatable, Sendable {
    case primary
    case secondary
}

public struct UsageWidgetConfiguration: Equatable, Sendable {
    public var bucket: UsageBucket

    public init(bucket: UsageBucket = .primary) {
        self.bucket = bucket
    }
}

public enum UsageWidget {
    public static func metric(
        snapshot: HabitatSnapshot?,
        bucket: UsageBucket
    ) -> MetricValue {
        let percent: Double?
        switch bucket {
        case .primary:
            percent = snapshot?.primaryRateLimit?.usedPercent
        case .secondary:
            percent = snapshot?.secondaryRateLimit?.usedPercent
        }
        guard let percent else { return .unavailable }
        return .percentage(min(max(percent, 0), 100))
    }
}

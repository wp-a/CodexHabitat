public struct CountdownConfiguration: Equatable, Sendable {
    public var durationSeconds: Int

    public init(durationSeconds: Int = 300) {
        self.durationSeconds = durationSeconds
    }

    func validate() throws {
        guard (1...86_400).contains(durationSeconds) else {
            throw WidgetConfigurationError.numericOutOfRange
        }
    }
}

public enum CountdownWidget {
    public static func metric(remainingSeconds: Int?) -> MetricValue {
        guard let remainingSeconds else { return .unavailable }
        return .durationSeconds(max(0, remainingSeconds))
    }
}

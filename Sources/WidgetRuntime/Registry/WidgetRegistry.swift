import HabitatCore

public struct WidgetRegistry: Sendable {
    public let descriptors: [WidgetDescriptor]

    public init(descriptors: [WidgetDescriptor]) {
        self.descriptors = descriptors
    }

    public static let builtIn = WidgetRegistry(descriptors: [
        WidgetDescriptor(
            id: .status,
            displayName: "Status",
            systemImage: "bolt.fill",
            defaultConfiguration: .status(StatusWidgetConfiguration())
        ),
        WidgetDescriptor(
            id: .usage,
            displayName: "Usage",
            systemImage: "gauge.with.dots.needle.50percent",
            defaultConfiguration: .usage(UsageWidgetConfiguration(bucket: .primary))
        ),
        WidgetDescriptor(
            id: .clock,
            displayName: "Clock",
            systemImage: "clock.fill",
            defaultConfiguration: .clock(ClockWidgetConfiguration())
        ),
        WidgetDescriptor(
            id: .pomodoro,
            displayName: "Pomodoro",
            systemImage: "timer",
            defaultConfiguration: .pomodoro(PomodoroConfiguration())
        ),
        WidgetDescriptor(
            id: .countdown,
            displayName: "Countdown",
            systemImage: "hourglass",
            defaultConfiguration: .countdown(CountdownConfiguration())
        ),
    ])

    public func descriptor(for id: WidgetIdentifier) -> WidgetDescriptor? {
        descriptors.first { $0.id == id }
    }

    public func validate(
        configuration: WidgetConfiguration,
        for id: WidgetIdentifier
    ) throws {
        switch (id, configuration) {
        case (.status, .status), (.usage, .usage), (.clock, .clock):
            return
        case let (.pomodoro, .pomodoro(configuration)):
            try configuration.validate()
        case let (.countdown, .countdown(configuration)):
            try configuration.validate()
        default:
            throw WidgetConfigurationError.configurationTypeMismatch
        }
    }
}

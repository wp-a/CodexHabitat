import HabitatCore

public enum WidgetConfigurationError: Error, Equatable, Sendable {
    case configurationTypeMismatch
    case numericOutOfRange
    case invalidPersistedState
}

public enum WidgetConfiguration: Equatable, Sendable {
    case status(StatusWidgetConfiguration)
    case usage(UsageWidgetConfiguration)
    case tokens(TokenWidgetConfiguration)
    case context(ContextWidgetConfiguration)
    case speed(SpeedWidgetConfiguration)
    case clock(ClockWidgetConfiguration)
    case pomodoro(PomodoroConfiguration)
    case countdown(CountdownConfiguration)
}

public struct WidgetDescriptor: Equatable, Sendable {
    public let id: WidgetIdentifier
    public let displayName: String
    public let systemImage: String
    public let defaultConfiguration: WidgetConfiguration

    public init(
        id: WidgetIdentifier,
        displayName: String,
        systemImage: String,
        defaultConfiguration: WidgetConfiguration
    ) {
        self.id = id
        self.displayName = displayName
        self.systemImage = systemImage
        self.defaultConfiguration = defaultConfiguration
    }
}

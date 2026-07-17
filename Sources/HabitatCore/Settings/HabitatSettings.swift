import Foundation

public enum WidgetIdentifier: String, Codable, CaseIterable, Equatable, Sendable {
    case status = "codex.status"
    case tokens = "codex.tokens"
    case context = "codex.context"
    case speed = "codex.speed"
    case usage = "codex.usage"
    case clock = "system.clock"
    case pomodoro = "timer.pomodoro"
    case countdown = "timer.countdown"
}

public enum ReduceMotionPreference: String, Codable, Equatable, Sendable {
    case system
    case reduce
    case full
}

public struct OverlayPosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct HabitatSettings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 4
    private static let themeBridgeSchemaVersion = 1
    private static let usefulMetricsSchemaVersion = 4
    private static let legacyDefaultWidgetOrder: [WidgetIdentifier] = [
        .status, .usage, .clock, .pomodoro,
    ]

    public var schemaVersion: Int
    public var selectedPetID: String?
    public var selectedThemeID: String
    public var widgetOrder: [WidgetIdentifier]
    public var overlayPositions: [String: OverlayPosition]
    public var scale: Double
    public var clickThrough: Bool
    public var positionLocked: Bool
    public var launchAtLogin: Bool
    public var reduceMotion: ReduceMotionPreference
    public var themeBridgeEnabled: Bool
    public var onboardingCompleted: Bool

    public static let `default` = HabitatSettings(
        schemaVersion: currentSchemaVersion,
        selectedPetID: nil,
        selectedThemeID: "workbench",
        widgetOrder: [.status, .tokens, .context, .speed, .usage],
        overlayPositions: [:],
        scale: 1,
        clickThrough: false,
        positionLocked: false,
        launchAtLogin: false,
        reduceMotion: .system,
        themeBridgeEnabled: false,
        onboardingCompleted: false
    )

    public init(
        schemaVersion: Int,
        selectedPetID: String?,
        selectedThemeID: String,
        widgetOrder: [WidgetIdentifier],
        overlayPositions: [String: OverlayPosition],
        scale: Double,
        clickThrough: Bool,
        positionLocked: Bool,
        launchAtLogin: Bool,
        reduceMotion: ReduceMotionPreference,
        themeBridgeEnabled: Bool,
        onboardingCompleted: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.selectedPetID = selectedPetID
        self.selectedThemeID = selectedThemeID
        self.widgetOrder = widgetOrder
        self.overlayPositions = overlayPositions
        self.scale = scale
        self.clickThrough = clickThrough
        self.positionLocked = positionLocked
        self.launchAtLogin = launchAtLogin
        self.reduceMotion = reduceMotion
        self.themeBridgeEnabled = themeBridgeEnabled
        self.onboardingCompleted = onboardingCompleted
    }

    public init(from decoder: any Decoder) throws {
        let defaults = HabitatSettings.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0

        schemaVersion = HabitatSettings.currentSchemaVersion
        selectedPetID = try container.decodeIfPresent(String.self, forKey: .selectedPetID)
        selectedThemeID = try container.decodeIfPresent(String.self, forKey: .selectedThemeID)
            ?? defaults.selectedThemeID
        let decodedWidgetOrder = try container.decodeIfPresent(
            [WidgetIdentifier].self,
            forKey: .widgetOrder
        )
        if storedSchemaVersion < HabitatSettings.usefulMetricsSchemaVersion,
           decodedWidgetOrder == HabitatSettings.legacyDefaultWidgetOrder {
            widgetOrder = defaults.widgetOrder
        } else {
            widgetOrder = decodedWidgetOrder ?? defaults.widgetOrder
        }
        overlayPositions = try container.decodeIfPresent(
            [String: OverlayPosition].self,
            forKey: .overlayPositions
        ) ?? defaults.overlayPositions
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? defaults.scale
        clickThrough = try container.decodeIfPresent(Bool.self, forKey: .clickThrough)
            ?? defaults.clickThrough
        positionLocked = try container.decodeIfPresent(Bool.self, forKey: .positionLocked)
            ?? defaults.positionLocked
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin)
            ?? defaults.launchAtLogin
        reduceMotion = try container.decodeIfPresent(
            ReduceMotionPreference.self,
            forKey: .reduceMotion
        ) ?? defaults.reduceMotion
        themeBridgeEnabled = storedSchemaVersion >= HabitatSettings.themeBridgeSchemaVersion
            ? try container.decodeIfPresent(Bool.self, forKey: .themeBridgeEnabled) ?? false
            : false
        onboardingCompleted = try container.decodeIfPresent(
            Bool.self,
            forKey: .onboardingCompleted
        ) ?? false
    }
}

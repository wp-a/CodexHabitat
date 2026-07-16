import Foundation

public enum WidgetIdentifier: String, Codable, CaseIterable, Equatable, Sendable {
    case status = "codex.status"
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
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var selectedPetID: String?
    public var selectedThemeID: String
    public var widgetOrder: [WidgetIdentifier]
    public var overlayPositions: [String: OverlayPosition]
    public var scale: Double
    public var clickThrough: Bool
    public var launchAtLogin: Bool
    public var reduceMotion: ReduceMotionPreference
    public var themeBridgeEnabled: Bool

    public static let `default` = HabitatSettings(
        schemaVersion: currentSchemaVersion,
        selectedPetID: nil,
        selectedThemeID: "workbench",
        widgetOrder: [.status, .usage, .clock, .pomodoro],
        overlayPositions: [:],
        scale: 1,
        clickThrough: false,
        launchAtLogin: false,
        reduceMotion: .system,
        themeBridgeEnabled: false
    )

    public init(
        schemaVersion: Int,
        selectedPetID: String?,
        selectedThemeID: String,
        widgetOrder: [WidgetIdentifier],
        overlayPositions: [String: OverlayPosition],
        scale: Double,
        clickThrough: Bool,
        launchAtLogin: Bool,
        reduceMotion: ReduceMotionPreference,
        themeBridgeEnabled: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.selectedPetID = selectedPetID
        self.selectedThemeID = selectedThemeID
        self.widgetOrder = widgetOrder
        self.overlayPositions = overlayPositions
        self.scale = scale
        self.clickThrough = clickThrough
        self.launchAtLogin = launchAtLogin
        self.reduceMotion = reduceMotion
        self.themeBridgeEnabled = themeBridgeEnabled
    }

    public init(from decoder: any Decoder) throws {
        let defaults = HabitatSettings.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0

        schemaVersion = HabitatSettings.currentSchemaVersion
        selectedPetID = try container.decodeIfPresent(String.self, forKey: .selectedPetID)
        selectedThemeID = try container.decodeIfPresent(String.self, forKey: .selectedThemeID)
            ?? defaults.selectedThemeID
        widgetOrder = try container.decodeIfPresent([WidgetIdentifier].self, forKey: .widgetOrder)
            ?? defaults.widgetOrder
        overlayPositions = try container.decodeIfPresent(
            [String: OverlayPosition].self,
            forKey: .overlayPositions
        ) ?? defaults.overlayPositions
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? defaults.scale
        clickThrough = try container.decodeIfPresent(Bool.self, forKey: .clickThrough)
            ?? defaults.clickThrough
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin)
            ?? defaults.launchAtLogin
        reduceMotion = try container.decodeIfPresent(
            ReduceMotionPreference.self,
            forKey: .reduceMotion
        ) ?? defaults.reduceMotion
        themeBridgeEnabled = storedSchemaVersion >= HabitatSettings.currentSchemaVersion
            ? try container.decodeIfPresent(Bool.self, forKey: .themeBridgeEnabled) ?? false
            : false
    }
}

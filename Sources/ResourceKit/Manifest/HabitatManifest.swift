import Foundation
import HabitatCore

public struct HabitatManifest: Decodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let name: String
    public let version: String
    public let author: String
    public let license: HabitatLicense
    public let minimumRuntimeVersion: String
    public let modes: [HabitatMode]
    public let preview: String
    public let colors: HabitatColorTokens
    public let assets: [HabitatResource]
    public let pets: [HabitatPetAdapter]
    public let widgets: [HabitatWidget]
}

public struct HabitatLicense: Decodable, Equatable, Sendable {
    public let spdx: String
    public let file: String
}

public enum HabitatMode: String, Decodable, Equatable, Sendable {
    case light
    case dark
}

public struct HabitatColorTokens: Decodable, Equatable, Sendable {
    public let surface: String
    public let text: String
    public let accent: String
    public let attention: String
    public let error: String

    var all: [(String, String)] {
        [
            ("surface", surface),
            ("text", text),
            ("accent", accent),
            ("attention", attention),
            ("error", error),
        ]
    }
}

public enum HabitatRendering: String, Decodable, Equatable, Sendable {
    case auto
    case pixelated
    case smooth
}

public struct HabitatImageResource: Decodable, Equatable, Sendable {
    public let id: String
    public let path: String
    public let sha256: String
    public let rendering: HabitatRendering
}

public struct HabitatFontResource: Decodable, Equatable, Sendable {
    public let id: String
    public let path: String
    public let sha256: String
}

public enum HabitatResource: Decodable, Equatable, Sendable {
    case image(HabitatImageResource)
    case font(HabitatFontResource)

    private enum Kind: String, Decodable {
        case image
        case font
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .image:
            self = .image(try HabitatImageResource(from: decoder))
        case .font:
            self = .font(try HabitatFontResource(from: decoder))
        }
    }
}

public struct HabitatPetAdapter: Decodable, Equatable, Sendable {
    public let id: String
    public let path: String
    public let rendering: HabitatRendering
    public let scale: Double
}

public enum HabitatAnchor: String, Decodable, Equatable, Sendable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case center
}

public struct HabitatRelativePosition: Decodable, Equatable, Sendable {
    public let x: Double
    public let y: Double
}

public struct HabitatWidget: Decodable, Equatable, Sendable {
    public let id: WidgetIdentifier
    public let anchor: HabitatAnchor
    public let position: HabitatRelativePosition
    public let configuration: HabitatWidgetConfiguration
}

public enum HabitatUsageBucket: String, Decodable, Equatable, Sendable {
    case primary
    case secondary
}

public struct HabitatStatusConfiguration: Decodable, Equatable, Sendable {
    public let showsConnectionHealth: Bool
}

public struct HabitatUsageConfiguration: Decodable, Equatable, Sendable {
    public let bucket: HabitatUsageBucket
}

public struct HabitatClockConfiguration: Decodable, Equatable, Sendable {
    public let uses24HourClock: Bool
}

public struct HabitatPomodoroConfiguration: Decodable, Equatable, Sendable {
    public let focusSeconds: Int
    public let restSeconds: Int
}

public struct HabitatCountdownConfiguration: Decodable, Equatable, Sendable {
    public let durationSeconds: Int
}

public enum HabitatWidgetConfiguration: Decodable, Equatable, Sendable {
    case status(HabitatStatusConfiguration)
    case usage(HabitatUsageConfiguration)
    case clock(HabitatClockConfiguration)
    case pomodoro(HabitatPomodoroConfiguration)
    case countdown(HabitatCountdownConfiguration)

    private enum Kind: String, Decodable {
        case status
        case usage
        case clock
        case pomodoro
        case countdown
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .status:
            self = .status(try HabitatStatusConfiguration(from: decoder))
        case .usage:
            self = .usage(try HabitatUsageConfiguration(from: decoder))
        case .clock:
            self = .clock(try HabitatClockConfiguration(from: decoder))
        case .pomodoro:
            self = .pomodoro(try HabitatPomodoroConfiguration(from: decoder))
        case .countdown:
            self = .countdown(try HabitatCountdownConfiguration(from: decoder))
        }
    }
}

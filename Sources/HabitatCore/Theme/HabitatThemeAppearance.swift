public enum HabitatThemeCategory: String, Codable, CaseIterable, Sendable {
    case utility
    case dark
    case game
    case cozy
    case nostalgia
    case chat
    case classic
    case animeEnergy
    case adventure
    case cozyAdventure
    case cinematic
    case fantasy
    case storybook
    case pixelGame
    case sports
    case custom

    public var localizationKey: String {
        "theme.category.\(rawValue)"
    }
}

public enum HabitatThemeStyleFamily: String, Codable, CaseIterable, Sendable {
    case arcade
    case retroMessenger
    case greenChat
    case classicDesktop
    case gameCinematic
    case cozyWorld
    case animeEnergy
    case fantasyAdventure
    case pixelWorld
}

public enum HabitatThemeSafeSide: String, Codable, CaseIterable, Sendable {
    case leading
    case trailing
}

public enum HabitatThemeDensity: String, Codable, CaseIterable, Sendable {
    case compact
    case comfortable
}

public struct HabitatThemeFocalPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct HabitatThemeAppearance: Codable, Equatable, Sendable {
    public let category: HabitatThemeCategory
    public let styleFamily: HabitatThemeStyleFamily
    public let background: String
    public let artFocus: HabitatThemeFocalPoint
    public let safeSide: HabitatThemeSafeSide
    public let backgroundStrength: Double
    public let panelOpacity: Double
    public let blurRadius: Double
    public let density: HabitatThemeDensity

    public init(
        category: HabitatThemeCategory,
        styleFamily: HabitatThemeStyleFamily,
        background: String,
        artFocus: HabitatThemeFocalPoint,
        safeSide: HabitatThemeSafeSide,
        backgroundStrength: Double,
        panelOpacity: Double,
        blurRadius: Double,
        density: HabitatThemeDensity
    ) {
        self.category = category
        self.styleFamily = styleFamily
        self.background = background
        self.artFocus = artFocus
        self.safeSide = safeSide
        self.backgroundStrength = backgroundStrength
        self.panelOpacity = panelOpacity
        self.blurRadius = blurRadius
        self.density = density
    }
}

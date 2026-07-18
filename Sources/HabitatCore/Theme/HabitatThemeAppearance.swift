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
    case center
    case none
}

public enum HabitatThemeDensity: String, Codable, CaseIterable, Sendable {
    case compact
    case comfortable
}

public enum HabitatThemeHomeMode: String, Codable, CaseIterable, Sendable {
    case immersive
    case framed
    case quiet
}

public enum HabitatThemeTaskMode: String, Codable, CaseIterable, Sendable {
    case ambient
    case banner
    case off
}

public enum HabitatThemeChromeMaterial: String, Codable, CaseIterable, Sendable {
    case solid
    case tinted
    case glass
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
    public let homeMode: HabitatThemeHomeMode?
    public let taskMode: HabitatThemeTaskMode?
    public let chromeMaterial: HabitatThemeChromeMaterial?
    public let homeStrength: Double?
    public let taskStrength: Double?
    public let sidebarOpacity: Double?
    public let headerOpacity: Double?
    public let composerOpacity: Double?

    public init(
        category: HabitatThemeCategory,
        styleFamily: HabitatThemeStyleFamily,
        background: String,
        artFocus: HabitatThemeFocalPoint,
        safeSide: HabitatThemeSafeSide,
        backgroundStrength: Double,
        panelOpacity: Double,
        blurRadius: Double,
        density: HabitatThemeDensity,
        homeMode: HabitatThemeHomeMode? = nil,
        taskMode: HabitatThemeTaskMode? = nil,
        chromeMaterial: HabitatThemeChromeMaterial? = nil,
        homeStrength: Double? = nil,
        taskStrength: Double? = nil,
        sidebarOpacity: Double? = nil,
        headerOpacity: Double? = nil,
        composerOpacity: Double? = nil
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
        self.homeMode = homeMode
        self.taskMode = taskMode
        self.chromeMaterial = chromeMaterial
        self.homeStrength = homeStrength
        self.taskStrength = taskStrength
        self.sidebarOpacity = sidebarOpacity
        self.headerOpacity = headerOpacity
        self.composerOpacity = composerOpacity
    }

    public var resolvedHomeMode: HabitatThemeHomeMode { homeMode ?? .quiet }
    public var resolvedTaskMode: HabitatThemeTaskMode { taskMode ?? .ambient }
    public var resolvedChromeMaterial: HabitatThemeChromeMaterial { chromeMaterial ?? .tinted }
    public var resolvedHomeStrength: Double { homeStrength ?? backgroundStrength }
    public var resolvedTaskStrength: Double { taskStrength ?? backgroundStrength * 0.46 }
    public var resolvedSidebarOpacity: Double { sidebarOpacity ?? panelOpacity }
    public var resolvedHeaderOpacity: Double { headerOpacity ?? panelOpacity }
    public var resolvedComposerOpacity: Double { composerOpacity ?? panelOpacity }
}

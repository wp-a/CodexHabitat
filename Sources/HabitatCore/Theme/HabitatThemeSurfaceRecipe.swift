public enum HabitatThemeSurfaceLineStyle: String, CaseIterable, Sendable {
    case solid
    case dashed
    case double
    case raised
}

public enum HabitatThemeSurfaceFocusStyle: String, CaseIterable, Sendable {
    case standard
    case solid
    case dotted
    case double
}

public enum HabitatThemeSurfaceMaterialStyle: String, CaseIterable, Sendable {
    case arcadeSignal
    case messengerGlass
    case chatUtility
    case desktopRaised
    case cinematicShade
    case cozySoft
    case energyStripe
    case fantasyOrnate
    case pixelHard
}

public struct HabitatThemeSurfaceRecipe: Equatable, Sendable {
    public let materialStyle: HabitatThemeSurfaceMaterialStyle
    public let headerEdgeWidth: Double
    public let headerLineStyle: HabitatThemeSurfaceLineStyle
    public let headerInsetDepth: Double
    public let actionRadius: Double
    public let actionEdgeWidth: Double
    public let actionLineStyle: HabitatThemeSurfaceLineStyle
    public let readingRadius: Double
    public let readingEdgeWidth: Double
    public let readingLineStyle: HabitatThemeSurfaceLineStyle
    public let composerRadius: Double
    public let composerEdgeWidth: Double
    public let composerShadowRadius: Double
    public let selectedRadius: Double
    public let selectedEdgeWidth: Double
    public let selectedShadowRadius: Double
    public let focusStyle: HabitatThemeSurfaceFocusStyle
    public let hoverEmphasisPercent: Int
    public let focusEmphasisPercent: Int
    public let innerHighlightPercent: Int

    public var signature: String {
        [
            materialStyle.rawValue,
            headerEdgeWidth.description,
            headerLineStyle.rawValue,
            headerInsetDepth.description,
            actionRadius.description,
            actionEdgeWidth.description,
            actionLineStyle.rawValue,
            readingRadius.description,
            readingEdgeWidth.description,
            readingLineStyle.rawValue,
            composerRadius.description,
            composerEdgeWidth.description,
            composerShadowRadius.description,
            selectedRadius.description,
            selectedEdgeWidth.description,
            selectedShadowRadius.description,
            focusStyle.rawValue,
            String(hoverEmphasisPercent),
            String(focusEmphasisPercent),
            String(innerHighlightPercent),
        ].joined(separator: "|")
    }
}

public extension HabitatThemeStyleFamily {
    var surfaceRecipe: HabitatThemeSurfaceRecipe {
        switch self {
        case .arcade:
            HabitatThemeSurfaceRecipe(
                materialStyle: .arcadeSignal,
                headerEdgeWidth: 1,
                headerLineStyle: .solid,
                headerInsetDepth: 2,
                actionRadius: 5,
                actionEdgeWidth: 1,
                actionLineStyle: .solid,
                readingRadius: 4,
                readingEdgeWidth: 1,
                readingLineStyle: .solid,
                composerRadius: 5,
                composerEdgeWidth: 1,
                composerShadowRadius: 4,
                selectedRadius: 5,
                selectedEdgeWidth: 1,
                selectedShadowRadius: 0,
                focusStyle: .solid,
                hoverEmphasisPercent: 90,
                focusEmphasisPercent: 78,
                innerHighlightPercent: 12
            )
        case .retroMessenger:
            HabitatThemeSurfaceRecipe(
                materialStyle: .messengerGlass,
                headerEdgeWidth: 1,
                headerLineStyle: .solid,
                headerInsetDepth: 3,
                actionRadius: 7,
                actionEdgeWidth: 1,
                actionLineStyle: .solid,
                readingRadius: 6,
                readingEdgeWidth: 1,
                readingLineStyle: .solid,
                composerRadius: 7,
                composerEdgeWidth: 1,
                composerShadowRadius: 3,
                selectedRadius: 6,
                selectedEdgeWidth: 1,
                selectedShadowRadius: 0,
                focusStyle: .standard,
                hoverEmphasisPercent: 90,
                focusEmphasisPercent: 78,
                innerHighlightPercent: 12
            )
        case .greenChat:
            HabitatThemeSurfaceRecipe(
                materialStyle: .chatUtility,
                headerEdgeWidth: 1,
                headerLineStyle: .solid,
                headerInsetDepth: 1,
                actionRadius: 6,
                actionEdgeWidth: 1,
                actionLineStyle: .solid,
                readingRadius: 5,
                readingEdgeWidth: 1,
                readingLineStyle: .solid,
                composerRadius: 6,
                composerEdgeWidth: 1,
                composerShadowRadius: 2,
                selectedRadius: 4,
                selectedEdgeWidth: 2,
                selectedShadowRadius: 0,
                focusStyle: .standard,
                hoverEmphasisPercent: 90,
                focusEmphasisPercent: 78,
                innerHighlightPercent: 12
            )
        case .classicDesktop:
            HabitatThemeSurfaceRecipe(
                materialStyle: .desktopRaised,
                headerEdgeWidth: 1,
                headerLineStyle: .raised,
                headerInsetDepth: 1,
                actionRadius: 0,
                actionEdgeWidth: 1,
                actionLineStyle: .raised,
                readingRadius: 0,
                readingEdgeWidth: 1,
                readingLineStyle: .raised,
                composerRadius: 0,
                composerEdgeWidth: 1,
                composerShadowRadius: 0,
                selectedRadius: 0,
                selectedEdgeWidth: 2,
                selectedShadowRadius: 0,
                focusStyle: .dotted,
                hoverEmphasisPercent: 90,
                focusEmphasisPercent: 78,
                innerHighlightPercent: 12
            )
        case .gameCinematic:
            HabitatThemeSurfaceRecipe(
                materialStyle: .cinematicShade,
                headerEdgeWidth: 1,
                headerLineStyle: .solid,
                headerInsetDepth: 1,
                actionRadius: 6,
                actionEdgeWidth: 1,
                actionLineStyle: .solid,
                readingRadius: 4,
                readingEdgeWidth: 1,
                readingLineStyle: .solid,
                composerRadius: 6,
                composerEdgeWidth: 1,
                composerShadowRadius: 6,
                selectedRadius: 4,
                selectedEdgeWidth: 1,
                selectedShadowRadius: 3,
                focusStyle: .solid,
                hoverEmphasisPercent: 90,
                focusEmphasisPercent: 78,
                innerHighlightPercent: 12
            )
        case .cozyWorld:
            HabitatThemeSurfaceRecipe(
                materialStyle: .cozySoft,
                headerEdgeWidth: 1,
                headerLineStyle: .solid,
                headerInsetDepth: 2,
                actionRadius: 10,
                actionEdgeWidth: 1,
                actionLineStyle: .solid,
                readingRadius: 10,
                readingEdgeWidth: 1,
                readingLineStyle: .solid,
                composerRadius: 10,
                composerEdgeWidth: 1,
                composerShadowRadius: 5,
                selectedRadius: 8,
                selectedEdgeWidth: 1,
                selectedShadowRadius: 0,
                focusStyle: .standard,
                hoverEmphasisPercent: 90,
                focusEmphasisPercent: 78,
                innerHighlightPercent: 12
            )
        case .animeEnergy:
            HabitatThemeSurfaceRecipe(
                materialStyle: .energyStripe,
                headerEdgeWidth: 1,
                headerLineStyle: .solid,
                headerInsetDepth: 2,
                actionRadius: 4,
                actionEdgeWidth: 1,
                actionLineStyle: .solid,
                readingRadius: 3,
                readingEdgeWidth: 1,
                readingLineStyle: .solid,
                composerRadius: 4,
                composerEdgeWidth: 1,
                composerShadowRadius: 4,
                selectedRadius: 3,
                selectedEdgeWidth: 2,
                selectedShadowRadius: 1,
                focusStyle: .solid,
                hoverEmphasisPercent: 90,
                focusEmphasisPercent: 78,
                innerHighlightPercent: 12
            )
        case .fantasyAdventure:
            HabitatThemeSurfaceRecipe(
                materialStyle: .fantasyOrnate,
                headerEdgeWidth: 1,
                headerLineStyle: .solid,
                headerInsetDepth: 3,
                actionRadius: 8,
                actionEdgeWidth: 1,
                actionLineStyle: .solid,
                readingRadius: 7,
                readingEdgeWidth: 1,
                readingLineStyle: .solid,
                composerRadius: 8,
                composerEdgeWidth: 1,
                composerShadowRadius: 5,
                selectedRadius: 7,
                selectedEdgeWidth: 1,
                selectedShadowRadius: 2,
                focusStyle: .solid,
                hoverEmphasisPercent: 90,
                focusEmphasisPercent: 78,
                innerHighlightPercent: 10
            )
        case .pixelWorld:
            HabitatThemeSurfaceRecipe(
                materialStyle: .pixelHard,
                headerEdgeWidth: 1,
                headerLineStyle: .solid,
                headerInsetDepth: 1,
                actionRadius: 2,
                actionEdgeWidth: 1,
                actionLineStyle: .solid,
                readingRadius: 2,
                readingEdgeWidth: 1,
                readingLineStyle: .solid,
                composerRadius: 2,
                composerEdgeWidth: 1,
                composerShadowRadius: 2,
                selectedRadius: 2,
                selectedEdgeWidth: 2,
                selectedShadowRadius: 2,
                focusStyle: .solid,
                hoverEmphasisPercent: 90,
                focusEmphasisPercent: 78,
                innerHighlightPercent: 12
            )
        }
    }
}

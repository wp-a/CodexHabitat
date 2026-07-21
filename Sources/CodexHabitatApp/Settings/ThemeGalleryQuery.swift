import Foundation
import HabitatCore

enum ThemeGalleryFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case nostalgia
    case chat
    case anime
    case games
    case cozy
    case classic
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .nostalgia: "Nostalgia"
        case .chat: "Chat"
        case .anime: "Anime"
        case .games: "Games"
        case .cozy: "Cozy"
        case .classic: "Classic"
        case .custom: "Custom"
        }
    }
}

enum ThemeGalleryQuery {
    static func filter(
        _ themes: [HabitatThemeDescriptor],
        by filter: ThemeGalleryFilter,
        search: String,
        localize: (String) -> String = { L10n.text($0) }
    ) -> [HabitatThemeDescriptor] {
        self.filter(
            themes,
            scope: .all,
            category: filter,
            search: search,
            favoriteThemeIDs: [],
            recentThemeIDs: [],
            localize: localize
        )
    }

    static func filter(
        _ themes: [HabitatThemeDescriptor],
        scope: ThemeLibraryScope,
        category: ThemeGalleryFilter,
        search: String,
        favoriteThemeIDs: [String],
        recentThemeIDs: [String],
        localize: (String) -> String = { L10n.text($0) }
    ) -> [HabitatThemeDescriptor] {
        let orderedThemes: [HabitatThemeDescriptor]
        switch scope {
        case .all:
            orderedThemes = themes
        case .favorites:
            orderedThemes = ordered(themes, by: favoriteThemeIDs)
        case .recent:
            orderedThemes = ordered(themes, by: recentThemeIDs)
        }

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return orderedThemes.filter { theme in
            guard includes(theme, in: category) else { return false }
            guard !query.isEmpty else { return true }
            let name = localize(theme.name)
            let category = localize(theme.category.localizationKey)
            return name.localizedCaseInsensitiveContains(query)
                || category.localizedCaseInsensitiveContains(query)
        }
    }

    private static func ordered(
        _ themes: [HabitatThemeDescriptor],
        by identifiers: [String]
    ) -> [HabitatThemeDescriptor] {
        let themesByID = Dictionary(uniqueKeysWithValues: themes.map { ($0.id, $0) })
        var seen: Set<String> = []
        return identifiers.compactMap { identifier in
            guard seen.insert(identifier).inserted else { return nil }
            return themesByID[identifier]
        }
    }

    private static func includes(
        _ theme: HabitatThemeDescriptor,
        in filter: ThemeGalleryFilter
    ) -> Bool {
        switch filter {
        case .all:
            true
        case .nostalgia:
            theme.category == .nostalgia
        case .chat:
            theme.category == .chat
        case .anime:
            theme.category == .animeEnergy
        case .games:
            [.game, .adventure, .cinematic, .fantasy, .pixelGame, .sports]
                .contains(theme.category)
        case .cozy:
            [.cozy, .cozyAdventure, .storybook].contains(theme.category)
        case .classic:
            theme.category == .classic
        case .custom:
            BuiltInThemeCatalog.definition(id: theme.id) == nil
        }
    }
}

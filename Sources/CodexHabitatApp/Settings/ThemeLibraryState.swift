import Foundation

enum ThemeLibraryScope: String, CaseIterable, Identifiable, Sendable {
    case all
    case favorites
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .recent: "Recent"
        }
    }
}

struct ThemeLibraryState: Equatable, Sendable {
    static let recentLimit = 12

    var scope = ThemeLibraryScope.all
    var category = ThemeGalleryFilter.all
    var searchText = ""
    var previewedThemeID: String?
    var previewRoute = ThemeTreatmentPreviewRoute.home
    private(set) var pendingApplyThemeID: String?

    init(previewedThemeID: String? = nil) {
        self.previewedThemeID = previewedThemeID
    }

    mutating func select(_ themeID: String) {
        previewedThemeID = themeID
        pendingApplyThemeID = nil
    }

    mutating func requestApply() {
        pendingApplyThemeID = previewedThemeID
    }

    mutating func clearPendingApply() {
        pendingApplyThemeID = nil
    }

    static func validFavorites(
        _ identifiers: [String],
        availableThemeIDs: Set<String>
    ) -> [String] {
        orderedUniqueValid(identifiers, availableThemeIDs: availableThemeIDs)
    }

    static func recordRecent(
        _ themeID: String,
        in identifiers: [String],
        availableThemeIDs: Set<String>
    ) -> [String] {
        guard availableThemeIDs.contains(themeID) else {
            return Array(orderedUniqueValid(
                identifiers,
                availableThemeIDs: availableThemeIDs
            ).prefix(recentLimit))
        }
        return Array(orderedUniqueValid(
            [themeID] + identifiers,
            availableThemeIDs: availableThemeIDs
        ).prefix(recentLimit))
    }

    private static func orderedUniqueValid(
        _ identifiers: [String],
        availableThemeIDs: Set<String>
    ) -> [String] {
        var seen: Set<String> = []
        return identifiers.filter {
            availableThemeIDs.contains($0) && seen.insert($0).inserted
        }
    }
}

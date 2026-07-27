import Foundation

enum HabitatVisualQAAppearance: String, Equatable, Sendable {
    case system
    case light
    case dark
}

struct HabitatVisualQALaunchOptions: Equatable, Sendable {
    let isEnabled: Bool
    let themeFilter: ThemeGalleryFilter
    let opensThemeStudio: Bool
    let collapsesOverlay: Bool
    let settingsWidth: Double
    let appearance: HabitatVisualQAAppearance

    static let disabled = HabitatVisualQALaunchOptions(
        isEnabled: false,
        themeFilter: .all,
        opensThemeStudio: false,
        collapsesOverlay: false,
        settingsWidth: 760,
        appearance: .system
    )

    static let current = HabitatVisualQALaunchOptions(arguments: CommandLine.arguments)

    init(arguments: [String]) {
        guard arguments.contains("--visual-qa") else {
            self = .disabled
            return
        }
        isEnabled = true
        themeFilter = Self.value(after: "--visual-qa-theme-filter", in: arguments)
            .flatMap(ThemeGalleryFilter.init(rawValue:)) ?? .all
        opensThemeStudio = arguments.contains("--visual-qa-theme-studio")
        collapsesOverlay = arguments.contains("--visual-qa-overlay-collapsed")
        let requestedWidth = Self.value(after: "--visual-qa-settings-width", in: arguments)
            .flatMap(Double.init) ?? 760
        settingsWidth = requestedWidth.isFinite ? min(max(requestedWidth, 760), 1_200) : 760
        appearance = Self.value(after: "--visual-qa-appearance", in: arguments)
            .flatMap(HabitatVisualQAAppearance.init(rawValue:)) ?? .system
    }

    private init(
        isEnabled: Bool,
        themeFilter: ThemeGalleryFilter,
        opensThemeStudio: Bool,
        collapsesOverlay: Bool,
        settingsWidth: Double,
        appearance: HabitatVisualQAAppearance
    ) {
        self.isEnabled = isEnabled
        self.themeFilter = themeFilter
        self.opensThemeStudio = opensThemeStudio
        self.collapsesOverlay = collapsesOverlay
        self.settingsWidth = settingsWidth
        self.appearance = appearance
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return arguments[index + 1]
    }
}

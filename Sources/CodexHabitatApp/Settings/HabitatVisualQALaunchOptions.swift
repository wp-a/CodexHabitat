import Foundation

struct HabitatVisualQALaunchOptions: Equatable, Sendable {
    let themeFilter: ThemeGalleryFilter
    let opensThemeStudio: Bool
    let collapsesOverlay: Bool
    let settingsWidth: Double

    static let disabled = HabitatVisualQALaunchOptions(
        themeFilter: .all,
        opensThemeStudio: false,
        collapsesOverlay: false,
        settingsWidth: 760
    )

    static var current: HabitatVisualQALaunchOptions {
        HabitatVisualQALaunchOptions(arguments: CommandLine.arguments)
    }

    init(arguments: [String]) {
        guard arguments.contains("--visual-qa") else {
            self = .disabled
            return
        }
        themeFilter = Self.value(after: "--visual-qa-theme-filter", in: arguments)
            .flatMap(ThemeGalleryFilter.init(rawValue:)) ?? .all
        opensThemeStudio = arguments.contains("--visual-qa-theme-studio")
        collapsesOverlay = arguments.contains("--visual-qa-overlay-collapsed")
        let requestedWidth = Self.value(after: "--visual-qa-settings-width", in: arguments)
            .flatMap(Double.init) ?? 760
        settingsWidth = requestedWidth.isFinite ? min(max(requestedWidth, 760), 1_200) : 760
    }

    private init(
        themeFilter: ThemeGalleryFilter,
        opensThemeStudio: Bool,
        collapsesOverlay: Bool,
        settingsWidth: Double
    ) {
        self.themeFilter = themeFilter
        self.opensThemeStudio = opensThemeStudio
        self.collapsesOverlay = collapsesOverlay
        self.settingsWidth = settingsWidth
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

import Foundation
import HabitatCore

struct HabitatOverviewState: Equatable {
    struct Content: Equatable {
        let key: String
        let count: Int?

        init(_ key: String, count: Int? = nil) {
            self.key = key
            self.count = count
        }

        var fallback: String {
            guard let count else { return key }
            return String(format: key, count)
        }

        var localized: String {
            guard let count else { return L10n.text(key) }
            return L10n.format(key, count)
        }
    }

    struct Section: Equatable, Identifiable {
        enum Kind: String, Equatable, CaseIterable {
            case habitat
            case codex
            case appearance
        }

        let kind: Kind
        let systemImage: String
        let primaryContent: Content
        let factContents: [Content]
        let action: Action

        var id: Kind { kind }
        var title: String { kind.title }
        var primary: String { primaryContent.fallback }
        var facts: [String] { factContents.map(\.fallback) }
    }

    enum Action: Equatable {
        case setHabitatVisibility(Bool)
        case navigate(SettingsSection)

        var content: Content {
            switch self {
            case let .setHabitatVisibility(isVisible):
                Content(isVisible ? "Show Habitat" : "Hide Habitat")
            case .navigate(.integrations):
                Content("Open Integrations")
            case .navigate(.themes):
                Content("Open Themes")
            case .navigate:
                Content("Open")
            }
        }
    }

    let sections: [Section]

    init(
        isHabitatVisible: Bool,
        selectedPetName: String?,
        positionLocked: Bool,
        enabledWidgetCount: Int,
        snapshot: HabitatSnapshot?,
        selectedThemeName: String?,
        themeSupportsCodexBridge: Bool,
        themeBridgeState: ThemeBridgeIntegrationState,
        canRestoreOfficialAppearance: Bool
    ) {
        self.init(
            isHabitatVisible: isHabitatVisible,
            selectedPetName: selectedPetName,
            positionLocked: positionLocked,
            enabledWidgetCount: enabledWidgetCount,
            connectionHealth: snapshot?.connectionHealth,
            hasSanitizedMetrics: snapshot.map(Self.hasSanitizedMetrics) ?? false,
            selectedThemeName: selectedThemeName,
            themeSupportsCodexBridge: themeSupportsCodexBridge,
            themeBridgeState: themeBridgeState,
            canRestoreOfficialAppearance: canRestoreOfficialAppearance
        )
    }

    init(
        isHabitatVisible: Bool,
        selectedPetName: String?,
        positionLocked: Bool,
        enabledWidgetCount: Int,
        connectionHealth: ConnectionHealth?,
        hasSanitizedMetrics: Bool,
        selectedThemeName: String?,
        themeSupportsCodexBridge: Bool,
        themeBridgeState: ThemeBridgeIntegrationState,
        canRestoreOfficialAppearance: Bool
    ) {
        let widgetFact = enabledWidgetCount > 0
            ? Content("%d widgets enabled", count: enabledWidgetCount)
            : Content("Widget rail off")
        sections = [
            Section(
                kind: .habitat,
                systemImage: "macwindow",
                primaryContent: Content(isHabitatVisible ? "Visible" : "Hidden"),
                factContents: [
                    Content(selectedPetName ?? "No pet selected"),
                    Content(positionLocked ? "Position locked" : "Position unlocked"),
                    widgetFact,
                ],
                action: .setHabitatVisibility(!isHabitatVisible)
            ),
            Section(
                kind: .codex,
                systemImage: "point.3.connected.trianglepath.dotted",
                primaryContent: Content(Self.connectionText(for: connectionHealth)),
                factContents: [
                    Content(hasSanitizedMetrics
                        ? "Sanitized metrics available"
                        : "Sanitized metrics unavailable"),
                    Content("Local read only"),
                ],
                action: .navigate(.integrations)
            ),
            Section(
                kind: .appearance,
                systemImage: "paintpalette",
                primaryContent: Content(selectedThemeName ?? "Default appearance"),
                factContents: [
                    Content(themeSupportsCodexBridge ? "Codex compatible" : "Habitat only"),
                    Content(Self.bridgeText(for: themeBridgeState)),
                    Content(canRestoreOfficialAppearance
                        ? "Restore available"
                        : "Official appearance"),
                ],
                action: .navigate(.themes)
            ),
        ]
    }

    private static func connectionText(for health: ConnectionHealth?) -> String {
        switch health {
        case .online: "Connected"
        case .estimated: "Estimated connection"
        case .reconnecting: "Reconnecting"
        case .offline: "Not connected"
        case nil: "Connection unavailable"
        }
    }

    private static func hasSanitizedMetrics(_ snapshot: HabitatSnapshot) -> Bool {
        snapshot.tokenMetrics != nil
            || snapshot.primaryRateLimit != nil
            || snapshot.secondaryRateLimit != nil
    }

    private static func bridgeText(for state: ThemeBridgeIntegrationState) -> String {
        switch state {
        case .unavailable: "Bridge unavailable"
        case .checking: "Bridge checking"
        case .ready: "Bridge ready"
        case .applying: "Bridge applying"
        case .active: "Bridge active"
        case .restoring: "Bridge restoring"
        case .failed: "Bridge needs attention"
        }
    }
}

private extension HabitatOverviewState.Section.Kind {
    var title: String {
        switch self {
        case .habitat: "Habitat"
        case .codex: "Codex"
        case .appearance: "Appearance"
        }
    }
}

import CoreGraphics

struct HabitatOverlayLayout: Equatable {
    static let collapsedSize = CGSize(width: 136, height: 144)
    static let expandedSize = CGSize(width: 324, height: 144)
    static let petSize = CGSize(width: 136, height: 144)
    static let widgetRailSize = CGSize(width: 176, height: 136)

    let isWidgetRailExpanded: Bool

    var containerSize: CGSize {
        isWidgetRailExpanded ? Self.expandedSize : Self.collapsedSize
    }

    var petFrame: CGRect {
        CGRect(
            x: containerSize.width - Self.petSize.width,
            y: 0,
            width: Self.petSize.width,
            height: Self.petSize.height
        )
    }

    var widgetRailFrame: CGRect? {
        guard isWidgetRailExpanded else { return nil }
        return CGRect(origin: CGPoint(x: 4, y: 4), size: Self.widgetRailSize)
    }
}

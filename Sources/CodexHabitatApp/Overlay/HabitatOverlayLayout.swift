import CoreGraphics

struct HabitatOverlayLayout: Equatable {
    static let containerSize = CGSize(width: 360, height: 180)
    static let petSize = CGSize(width: 160, height: 180)
    static let widgetRailSize = CGSize(width: 184, height: 172)

    let isWidgetRailExpanded: Bool

    var containerSize: CGSize { Self.containerSize }

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

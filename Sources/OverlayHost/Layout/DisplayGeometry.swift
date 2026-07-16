import CoreGraphics
import Foundation

public struct RelativeOverlayPosition: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }
}

public struct SavedOverlayPlacement: Codable, Equatable, Sendable {
    public let displayID: String
    public let relativePosition: RelativeOverlayPosition

    public init(displayID: String, relativePosition: RelativeOverlayPosition) {
        self.displayID = displayID
        self.relativePosition = relativePosition
    }
}

public struct ResolvedOverlayPlacement: Equatable, Sendable {
    public let display: DisplayGeometry
    public let origin: CGPoint

    public init(display: DisplayGeometry, origin: CGPoint) {
        self.display = display
        self.origin = origin
    }
}

public struct DisplayGeometry: Equatable, Sendable {
    public let id: String
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let backingScaleFactor: CGFloat

    public init(
        id: String,
        frame: CGRect,
        visibleFrame: CGRect,
        backingScaleFactor: CGFloat
    ) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.backingScaleFactor = backingScaleFactor
    }

    public func clampedOrigin(_ origin: CGPoint, panelSize: CGSize) -> CGPoint {
        let maximumX = max(visibleFrame.minX, visibleFrame.maxX - panelSize.width)
        let maximumY = max(visibleFrame.minY, visibleFrame.maxY - panelSize.height)
        return CGPoint(
            x: min(max(origin.x, visibleFrame.minX), maximumX),
            y: min(max(origin.y, visibleFrame.minY), maximumY)
        )
    }

    public func relativePosition(
        for origin: CGPoint,
        panelSize: CGSize
    ) -> RelativeOverlayPosition {
        let clamped = clampedOrigin(origin, panelSize: panelSize)
        let horizontalTravel = max(0, visibleFrame.width - panelSize.width)
        let verticalTravel = max(0, visibleFrame.height - panelSize.height)
        return RelativeOverlayPosition(
            x: horizontalTravel == 0 ? 0 : Double((clamped.x - visibleFrame.minX) / horizontalTravel),
            y: verticalTravel == 0 ? 0 : Double((clamped.y - visibleFrame.minY) / verticalTravel)
        )
    }

    public func origin(
        for relativePosition: RelativeOverlayPosition,
        panelSize: CGSize
    ) -> CGPoint {
        let horizontalTravel = max(0, visibleFrame.width - panelSize.width)
        let verticalTravel = max(0, visibleFrame.height - panelSize.height)
        return clampedOrigin(
            CGPoint(
                x: visibleFrame.minX + horizontalTravel * CGFloat(relativePosition.x),
                y: visibleFrame.minY + verticalTravel * CGFloat(relativePosition.y)
            ),
            panelSize: panelSize
        )
    }

    public static func resolve(
        saved: SavedOverlayPlacement,
        panelSize: CGSize,
        displays: [DisplayGeometry],
        fallbackDisplayID: String? = nil
    ) -> ResolvedOverlayPlacement? {
        guard !displays.isEmpty else { return nil }
        let display = displays.first(where: { $0.id == saved.displayID })
            ?? fallbackDisplayID.flatMap { id in displays.first(where: { $0.id == id }) }
            ?? displays[0]
        return ResolvedOverlayPlacement(
            display: display,
            origin: display.origin(for: saved.relativePosition, panelSize: panelSize)
        )
    }
}

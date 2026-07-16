import CoreGraphics

public struct EdgeSnapper: Equatable, Sendable {
    public let threshold: CGFloat

    public init(threshold: CGFloat = 12) {
        self.threshold = max(0, threshold)
    }

    public func snappedOrigin(
        _ origin: CGPoint,
        panelSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        let geometry = DisplayGeometry(
            id: "snap",
            frame: visibleFrame,
            visibleFrame: visibleFrame,
            backingScaleFactor: 1
        )
        var result = geometry.clampedOrigin(origin, panelSize: panelSize)
        let rightOrigin = max(visibleFrame.minX, visibleFrame.maxX - panelSize.width)
        let topOrigin = max(visibleFrame.minY, visibleFrame.maxY - panelSize.height)

        if abs(result.x - visibleFrame.minX) <= threshold {
            result.x = visibleFrame.minX
        } else if abs(result.x - rightOrigin) <= threshold {
            result.x = rightOrigin
        }
        if abs(result.y - visibleFrame.minY) <= threshold {
            result.y = visibleFrame.minY
        } else if abs(result.y - topOrigin) <= threshold {
            result.y = topOrigin
        }
        return result
    }
}

public struct HabitatThemeArtworkCrop: Equatable, Sendable {
    public struct Size: Equatable, Sendable {
        public let width: Double
        public let height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    public struct Rect: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)
    }

    public let focus: HabitatThemeFocalPoint
    public let scale: Double

    public init(focus: HabitatThemeFocalPoint, scale: Double) {
        self.focus = focus
        self.scale = scale
    }

    public func drawRect(imageSize: Size, viewportSize: Size) -> Rect {
        guard imageSize.width.isFinite, imageSize.width > 0,
              imageSize.height.isFinite, imageSize.height > 0,
              viewportSize.width.isFinite, viewportSize.width > 0,
              viewportSize.height.isFinite, viewportSize.height > 0,
              focus.x.isFinite, focus.y.isFinite,
              scale.isFinite, scale > 0
        else {
            return .zero
        }

        let coverScale = max(
            viewportSize.width / imageSize.width,
            viewportSize.height / imageSize.height
        )
        let width = imageSize.width * coverScale * scale
        let height = imageSize.height * coverScale * scale
        return Rect(
            x: (viewportSize.width - width) * focus.x,
            y: (viewportSize.height - height) * focus.y,
            width: width,
            height: height
        )
    }
}

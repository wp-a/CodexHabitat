import CoreGraphics
import Foundation
import ImageIO

public struct SpriteSheetRenderer: Sendable {
    private let frames: [CGImage]
    public let atlas: PetAtlasMetadata
    public var isRenderable: Bool { !frames.isEmpty }

    public init(image: CGImage?, atlas: PetAtlasMetadata) {
        self.atlas = atlas
        frames = Self.precroppedFrames(image: image, atlas: atlas)
    }

    public init(contentsOf url: URL, atlas: PetAtlasMetadata) {
        self.atlas = atlas
        guard !Task.isCancelled else {
            frames = []
            return
        }
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        frames = Self.precroppedFrames(
            image: Task.isCancelled
                ? nil
                : source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) },
            atlas: atlas
        )
    }

    public static func frame(
        contentsOf url: URL,
        atlas: PetAtlasMetadata,
        row: Int,
        column: Int
    ) -> CGImage? {
        guard atlas.pixelWidth > 0,
              atlas.pixelHeight > 0,
              atlas.columns > 0,
              atlas.rows > 0,
              atlas.pixelWidth.isMultiple(of: atlas.columns),
              atlas.pixelHeight.isMultiple(of: atlas.rows),
              row >= 0,
              row < atlas.rows,
              column >= 0,
              column < atlas.columns,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width == atlas.pixelWidth,
              image.height == atlas.pixelHeight
        else {
            return nil
        }
        let rect = CGRect(
            x: column * atlas.cellWidth,
            y: row * atlas.cellHeight,
            width: atlas.cellWidth,
            height: atlas.cellHeight
        )
        return normalizedFrame(image: image, rect: rect, atlas: atlas)
    }

    public func sourceRect(row: Int, column: Int) -> CGRect? {
        guard row >= 0,
              row < atlas.rows,
              column >= 0,
              column < atlas.columns
        else {
            return nil
        }
        return CGRect(
            x: column * atlas.cellWidth,
            y: row * atlas.cellHeight,
            width: atlas.cellWidth,
            height: atlas.cellHeight
        )
    }

    public func frame(_ frame: PetFrame) -> CGImage? {
        self.frame(row: frame.row, column: frame.column)
    }

    public func frame(row: Int, column: Int) -> CGImage? {
        guard sourceRect(row: row, column: column) != nil,
              frames.count == atlas.rows * atlas.columns
        else {
            return nil
        }
        return frames[row * atlas.columns + column]
    }

    private static func precroppedFrames(
        image: CGImage?,
        atlas: PetAtlasMetadata
    ) -> [CGImage] {
        guard !Task.isCancelled,
              let image,
              image.width == atlas.pixelWidth,
              image.height == atlas.pixelHeight
        else {
            return []
        }
        var result: [CGImage] = []
        result.reserveCapacity(atlas.rows * atlas.columns)
        for row in 0..<atlas.rows {
            for column in 0..<atlas.columns {
                guard !Task.isCancelled else { return [] }
                let rect = CGRect(
                    x: column * atlas.cellWidth,
                    y: row * atlas.cellHeight,
                    width: atlas.cellWidth,
                    height: atlas.cellHeight
                )
                guard let frame = normalizedFrame(image: image, rect: rect, atlas: atlas) else {
                    return []
                }
                result.append(frame)
            }
        }
        return result
    }

    private static func normalizedFrame(
        image: CGImage,
        rect: CGRect,
        atlas: PetAtlasMetadata
    ) -> CGImage? {
        guard let crop = image.cropping(to: rect),
              let context = CGContext(
                data: nil,
                width: atlas.cellWidth,
                height: atlas.cellHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }
        context.interpolationQuality = .none
        context.draw(
            crop,
            in: CGRect(
                x: 0,
                y: 0,
                width: atlas.cellWidth,
                height: atlas.cellHeight
            )
        )
        return context.makeImage()
    }
}

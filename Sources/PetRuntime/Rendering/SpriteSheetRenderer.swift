import CoreGraphics
import Foundation
import ImageIO

public struct SpriteSheetRenderer {
    private let frames: [CGImage]
    public let atlas: PetAtlasMetadata

    public init(image: CGImage?, atlas: PetAtlasMetadata) {
        self.atlas = atlas
        frames = Self.precroppedFrames(image: image, atlas: atlas)
    }

    public init(contentsOf url: URL, atlas: PetAtlasMetadata) {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        self.atlas = atlas
        frames = Self.precroppedFrames(
            image: source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) },
            atlas: atlas
        )
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
        guard let image,
              image.width == atlas.pixelWidth,
              image.height == atlas.pixelHeight
        else {
            return []
        }
        var result: [CGImage] = []
        result.reserveCapacity(atlas.rows * atlas.columns)
        for row in 0..<atlas.rows {
            for column in 0..<atlas.columns {
                let rect = CGRect(
                    x: column * atlas.cellWidth,
                    y: row * atlas.cellHeight,
                    width: atlas.cellWidth,
                    height: atlas.cellHeight
                )
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
                    return []
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
                guard let frame = context.makeImage() else { return [] }
                result.append(frame)
            }
        }
        return result
    }
}

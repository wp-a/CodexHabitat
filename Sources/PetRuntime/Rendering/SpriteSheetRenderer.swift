import CoreGraphics
import Foundation
import ImageIO

public struct SpriteSheetRenderer {
    private let image: CGImage?
    public let atlas: PetAtlasMetadata

    public init(image: CGImage?, atlas: PetAtlasMetadata) {
        self.image = image
        self.atlas = atlas
    }

    public init(contentsOf url: URL, atlas: PetAtlasMetadata) {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        image = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        self.atlas = atlas
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
        guard let image,
              image.width == atlas.pixelWidth,
              image.height == atlas.pixelHeight,
              let rect = sourceRect(row: row, column: column)
        else {
            return nil
        }
        return image.cropping(to: rect)
    }
}

import CoreGraphics
import Foundation
import Testing
@testable import PetRuntime

@Test
func sourceRectUsesIntegralAtlasPixels() throws {
    let image = try testImage(width: 32, height: 36)
    let renderer = SpriteSheetRenderer(
        image: image,
        atlas: PetAtlasMetadata(pixelWidth: 32, pixelHeight: 36, columns: 8, rows: 9)
    )

    #expect(renderer.sourceRect(row: 2, column: 3) == CGRect(x: 12, y: 8, width: 4, height: 4))
    #expect(renderer.sourceRect(row: -1, column: 0) == nil)
    #expect(renderer.sourceRect(row: 0, column: 8) == nil)
}

@Test
func croppedFramesKeepSourcePixelSizeAtRetinaDestinations() throws {
    let image = try testImage(width: 32, height: 36)
    let renderer = SpriteSheetRenderer(
        image: image,
        atlas: PetAtlasMetadata(pixelWidth: 32, pixelHeight: 36, columns: 8, rows: 9)
    )

    let frame = try #require(renderer.frame(row: 4, column: 5))

    #expect(frame.width == 4)
    #expect(frame.height == 4)
}

@Test
func repeatedFrameReadsReuseThePrecroppedImage() throws {
    let image = try testImage(width: 32, height: 36)
    let renderer = SpriteSheetRenderer(
        image: image,
        atlas: PetAtlasMetadata(pixelWidth: 32, pixelHeight: 36, columns: 8, rows: 9)
    )

    let first = try #require(renderer.frame(row: 4, column: 5))
    let second = try #require(renderer.frame(row: 4, column: 5))

    #expect(first === second)
}

@Test
func transparentPaddingSurvivesCropping() throws {
    let image = try testImage(width: 32, height: 36) { context in
        context.setFillColor(CGColor(red: 0.1, green: 0.8, blue: 0.7, alpha: 1))
        // CGContext draws from bottom-left; atlas row coordinates start at top-left.
        context.fill(CGRect(x: 13, y: 25, width: 2, height: 2))
    }
    let renderer = SpriteSheetRenderer(
        image: image,
        atlas: PetAtlasMetadata(pixelWidth: 32, pixelHeight: 36, columns: 8, rows: 9)
    )

    let frame = try #require(renderer.frame(row: 2, column: 3))

    #expect(alpha(frame, x: 0, y: 0) == 0)
    #expect(alpha(frame, x: 1, y: 1) == 255)
    #expect(alpha(frame, x: 3, y: 3) == 0)
}

@Test
func mismatchedOrUnreadableImagesReturnFallbackNil() throws {
    let wrongSize = try testImage(width: 31, height: 36)
    let metadata = PetAtlasMetadata(pixelWidth: 32, pixelHeight: 36, columns: 8, rows: 9)

    #expect(SpriteSheetRenderer(image: wrongSize, atlas: metadata).frame(row: 0, column: 0) == nil)
    #expect(SpriteSheetRenderer(image: nil, atlas: metadata).frame(row: 0, column: 0) == nil)
}

private func testImage(
    width: Int,
    height: Int,
    draw: (CGContext) -> Void = { _ in }
) throws -> CGImage {
    let context = try #require(
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    draw(context)
    return try #require(context.makeImage())
}

private func alpha(_ image: CGImage, x: Int, y: Int) -> UInt8? {
    guard let data = image.dataProvider?.data,
          let bytes = CFDataGetBytePtr(data)
    else {
        return nil
    }
    return bytes[y * image.bytesPerRow + x * 4 + 3]
}

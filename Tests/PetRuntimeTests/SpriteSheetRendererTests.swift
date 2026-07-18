import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
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
func cancelledRendererBuildSkipsFramePrecropping() async throws {
    let image = try testImage(width: 32, height: 36)
    let atlas = PetAtlasMetadata(pixelWidth: 32, pixelHeight: 36, columns: 8, rows: 9)
    let gate = RendererCancellationGate()
    let task = Task.detached {
        await gate.wait()
        return SpriteSheetRenderer(image: image, atlas: atlas)
    }

    for _ in 0..<1_000 where await !gate.hasWaiter {
        await Task.yield()
    }
    task.cancel()
    await gate.release()
    let renderer = await task.value

    #expect(renderer.frame(row: 0, column: 0) == nil)
}

private actor RendererCancellationGate {
    private var continuation: CheckedContinuation<Void, Never>?

    var hasWaiter: Bool { continuation != nil }

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
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

@Test
func singleFrameLoadingReturnsOnlyTheRequestedNormalizedCell() throws {
    let image = try testImage(width: 8, height: 9) { context in
        context.setFillColor(CGColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 1, y: 8, width: 1, height: 1))
    }
    let url = try temporaryPNG(for: image)
    defer { try? FileManager.default.removeItem(at: url) }
    let atlas = PetAtlasMetadata(pixelWidth: 8, pixelHeight: 9, columns: 8, rows: 9)

    let selected = try #require(SpriteSheetRenderer.frame(
        contentsOf: url,
        atlas: atlas,
        row: 0,
        column: 1
    ))
    let adjacent = try #require(SpriteSheetRenderer.frame(
        contentsOf: url,
        atlas: atlas,
        row: 0,
        column: 0
    ))

    #expect(selected.width == 1)
    #expect(selected.height == 1)
    #expect(alpha(selected, x: 0, y: 0) == 255)
    #expect(alpha(adjacent, x: 0, y: 0) == 0)
    #expect(SpriteSheetRenderer.frame(
        contentsOf: url,
        atlas: atlas,
        row: -1,
        column: 0
    ) == nil)
    #expect(SpriteSheetRenderer.frame(
        contentsOf: url,
        atlas: PetAtlasMetadata(pixelWidth: 16, pixelHeight: 9, columns: 8, rows: 9),
        row: 0,
        column: 0
    ) == nil)
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

private func temporaryPNG(for image: CGImage) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatSprite-\(UUID().uuidString).png")
    let destination = try #require(CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

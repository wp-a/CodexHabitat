import CoreGraphics
import Foundation
import Testing
@testable import CodexHabitatApp

@Test
func repeatedThemePreviewRequestsReuseOneDownsampledImage() async throws {
    let image = try themePreviewTestImage()
    let counter = ThemePreviewLoadCounter()
    let store = ThemePreviewStore { _ in
        counter.increment()
        return image
    }
    let previewURL = URL(fileURLWithPath: "/tmp/test-theme-preview.png")

    let first = await store.image(at: previewURL)
    let second = await store.image(at: previewURL)

    #expect(first === image)
    #expect(second === image)
    #expect(counter.value == 1)
}

@Test
func missingThemePreviewResultsAreCached() async {
    let counter = ThemePreviewLoadCounter()
    let store = ThemePreviewStore { _ in
        counter.increment()
        return nil
    }
    let previewURL = URL(fileURLWithPath: "/tmp/test-missing-theme-preview.png")

    #expect(await store.image(at: previewURL) == nil)
    #expect(await store.image(at: previewURL) == nil)
    #expect(counter.value == 1)
}

@Test
func replacingAThemePreviewInvalidatesItsCachedImage() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemePreviewTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let previewURL = root.appending(path: "preview.png")
    try Data([0]).write(to: previewURL)

    let image = try themePreviewTestImage()
    let counter = ThemePreviewLoadCounter()
    let store = ThemePreviewStore { _ in
        counter.increment()
        return image
    }

    _ = await store.image(at: previewURL)
    try Data([0, 1]).write(to: previewURL)
    _ = await store.image(at: previewURL)

    #expect(counter.value == 2)
}

private final class ThemePreviewLoadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private func themePreviewTestImage() throws -> CGImage {
    let context = try #require(CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    return try #require(context.makeImage())
}

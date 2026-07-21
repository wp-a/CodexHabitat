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
func failedThemePreviewCanBeExplicitlyInvalidatedAndRetried() async throws {
    let image = try themePreviewTestImage()
    let counter = ThemePreviewLoadCounter()
    let store = ThemePreviewStore { _ in
        counter.increment()
        return counter.value == 1 ? nil : image
    }
    let previewURL = URL(fileURLWithPath: "/tmp/test-retry-theme-preview.png")

    #expect(await store.image(at: previewURL) == nil)
    await store.invalidate(url: previewURL)
    #expect(await store.image(at: previewURL) === image)
    #expect(counter.value == 2)
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

@Test
func replacingAThemePreviewChangesTheViewRequestIdentity() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemePreviewIdentity-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let previewURL = root.appending(path: "preview.png")
    try Data([0]).write(to: previewURL)
    let first = ThemePreviewRequestKey(url: previewURL)

    try Data([0, 1]).write(to: previewURL)
    let second = ThemePreviewRequestKey(url: previewURL)

    #expect(first != second)
}

@Test
func galleryPlansUseOnlyStaticPackagedPreviewsWithoutBackdropMaterial() throws {
    #expect(HabitatThemeDescriptor.builtIn.count == 24)
    for theme in HabitatThemeDescriptor.builtIn {
        let plan = ThemeGalleryPreviewPlan(theme: theme)
        #expect(plan.imageURL == theme.previewURL)
        #expect(plan.usesStaticThumbnail)
        #expect(!plan.usesBackdropMaterial)
    }

    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift"
        ),
        encoding: .utf8
    )
    let cardStart = try #require(source.range(of: "struct ThemeChoiceCard"))
    let thumbnailStart = try #require(source.range(of: "struct StaticThemeThumbnail"))
    let thumbnailSource = source[thumbnailStart.lowerBound..<cardStart.lowerBound]
    let cardSource = source[cardStart.lowerBound...]
    #expect(cardSource.contains("StaticThemeThumbnail"))
    #expect(!cardSource.contains("ThemeTreatmentPreview("))
    #expect(!cardSource.contains("ultraThinMaterial"))
    #expect(!thumbnailSource.contains(".stroke("))
    #expect(cardSource.contains(".lineLimit(2)"))
    #expect(cardSource.contains(".frame(height: 46)"))
    #expect(cardSource.contains("isSelected ? \"Selected\" : \"Not selected\""))
    #expect(cardSource.contains("isActive ? \"Active\" : \"Inactive\""))
    #expect(cardSource.contains("isFavorite ? \"Favorite\" : \"Not favorite\""))
}

@Test
func treatmentPreviewClearsOldFailureBeforeStartingAReplacementLoad() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift"
        ),
        encoding: .utf8
    )
    let taskStart = try #require(source.range(of: ".task(id: previewLoadIdentity)"))
    let taskSource = source[taskStart.lowerBound...]
    let reset = try #require(taskSource.range(of: "previewLoadFailed = false"))
    let load = try #require(taskSource.range(of: "ThemePreviewStore.shared.image"))

    #expect(reset.lowerBound < load.lowerBound)
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

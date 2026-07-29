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
func themePreviewCacheEvictsLeastRecentImagesPastItsCostBudget() async throws {
    let image = try themePreviewTestImage()
    let counter = ThemePreviewLoadCounter()
    let store = ThemePreviewStore(maximumCacheCost: 4) { _ in
        counter.increment()
        return image
    }
    let firstURL = URL(fileURLWithPath: "/tmp/theme-preview-budget-first.png")
    let secondURL = URL(fileURLWithPath: "/tmp/theme-preview-budget-second.png")

    _ = await store.image(at: firstURL)
    _ = await store.image(at: secondURL)
    _ = await store.image(at: firstURL)

    #expect(counter.value == 3)
}

@Test
func differentThemePreviewsDecodeConcurrently() async {
    let probe = ConcurrentThemePreviewProbe()
    let store = ThemePreviewStore { _ in
        probe.begin()
        Thread.sleep(forTimeInterval: 0.04)
        probe.end()
        return nil
    }

    async let first = store.image(at: URL(fileURLWithPath: "/tmp/theme-preview-first.png"))
    async let second = store.image(at: URL(fileURLWithPath: "/tmp/theme-preview-second.png"))
    _ = await (first, second)

    #expect(probe.maximumConcurrentLoads == 2)
}

@Test
func concurrentRequestsForTheSameThemePreviewShareOneDecode() async {
    let counter = ThemePreviewLoadCounter()
    let store = ThemePreviewStore { _ in
        counter.increment()
        Thread.sleep(forTimeInterval: 0.04)
        return nil
    }
    let previewURL = URL(fileURLWithPath: "/tmp/theme-preview-shared.png")

    async let first = store.image(at: previewURL)
    async let second = store.image(at: previewURL)
    _ = await (first, second)

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
func themePreviewPixelSizeChangesTheRequestIdentity() {
    let previewURL = URL(fileURLWithPath: "/tmp/theme-preview-size.png")

    let card = ThemePreviewRequestKey(url: previewURL, maximumPixelSize: 480)
    let inspector = ThemePreviewRequestKey(url: previewURL, maximumPixelSize: 720)

    #expect(card != inspector)
}

@Test
func themePreviewViewIdentityDoesNotSynchronouslyTrackFileRevision() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeViewIdentity-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let previewURL = root.appending(path: "preview.png")
    try Data([0]).write(to: previewURL)
    let first = ThemePreviewLoadIdentity(url: previewURL, reloadGeneration: 0)

    try Data([0, 1]).write(to: previewURL)
    let second = ThemePreviewLoadIdentity(url: previewURL, reloadGeneration: 0)
    let retry = ThemePreviewLoadIdentity(url: previewURL, reloadGeneration: 1)

    #expect(first == second)
    #expect(first != retry)
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
    #expect(!cardSource.contains("maxHeight: 172"))
    #expect(cardSource.contains("isPreviewed ? \"Previewed\" : \"Not previewed\""))
    #expect(cardSource.contains("isActiveInHabitat ? \"Active in Habitat\" : \"Inactive in Habitat\""))
    #expect(cardSource.contains("isActiveInCodex ? \"Active in Codex\" : \"Inactive in Codex\""))
    #expect(cardSource.contains("isFavorite ? \"Favorite\" : \"Not favorite\""))
    #expect(cardSource.contains("themes.choice.\\(theme.id).retry"))
    #expect(cardSource.contains("Retry %@ preview"))
    let cardButton = try #require(cardSource.range(of: "Button(action: action)"))
    let retryButton = try #require(cardSource.range(of: "Button(action: retryPreview)"))
    #expect(retryButton.lowerBound > cardButton.upperBound)
    #expect(cardSource.contains("ZStack(alignment: .center)"))
    let favoriteOverlay = try #require(cardSource.range(of: ".overlay(alignment: .topTrailing)"))
    let retryControlSource = cardSource[retryButton.lowerBound..<favoriteOverlay.lowerBound]
    #expect(!retryControlSource.contains("maxWidth: .infinity"))
}

@Test
func themeInspectorUsesScrollableDetailsAndAPinnedActionBar() throws {
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
    let inspectorStart = try #require(source.range(of: "private var themeInspector"))
    let selectedThemeStart = try #require(source.range(of: "private var selectedTheme"))
    let inspectorSource = source[inspectorStart.lowerBound..<selectedThemeStart.lowerBound]

    #expect(inspectorSource.contains("ScrollView"))
    #expect(inspectorSource.contains("inspectorContent"))
    #expect(inspectorSource.contains("inspectorActions"))
    #expect(!inspectorSource.contains("Spacer(minLength: 0)"))
}

@Test
func themeLibraryKeepsLongBridgeStatusReadableAndUsesOneCardBoundary() throws {
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
    let bridgeStatusStart = try #require(source.range(of: "private var inspectorBridgeStatus"))
    let statusCellStart = try #require(source.range(of: "private func inspectorStatusCell"))
    let bridgeStatusSource = source[bridgeStatusStart.lowerBound..<statusCellStart.lowerBound]
    #expect(bridgeStatusSource.contains("valueLineLimit: 2"))
    #expect(bridgeStatusSource.contains("maxWidth: .infinity"))

    let cardStart = try #require(source.range(of: "struct ThemeChoiceCard"))
    let cardSource = source[cardStart.lowerBound...]
    #expect(cardSource.contains("if !isPreviewed"))
}

@Test
func treatmentPreviewUsesRequestStateToClearFailedReplacementImages() throws {
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
    #expect(source.contains("ThemePreviewPresentationState"))
    #expect(source.contains("presentationState.beginRequest()"))
    #expect(source.contains("case .clearImage:"))
    #expect(source.contains("image = nil"))
    #expect(source.contains("case .ignored:"))
    #expect(source.contains(".accessibilityHidden(true)"))
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

private final class ConcurrentThemePreviewProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var activeLoads = 0
    private var maximum = 0

    var maximumConcurrentLoads: Int {
        lock.withLock { maximum }
    }

    func begin() {
        lock.withLock {
            activeLoads += 1
            maximum = max(maximum, activeLoads)
        }
    }

    func end() {
        lock.withLock { activeLoads -= 1 }
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

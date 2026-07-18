import Foundation
import HabitatCore
import ImageIO
import Testing
@testable import ResourceKit

@Test
func themePackageBuilderCreatesDeterministicInstallableThemeArchive() throws {
    let root = temporaryBuilderRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source.png")
    try testPNG(width: 2_000, height: 1_200).write(to: source)
    let work = root.appending(path: "Work", directoryHint: .isDirectory)
    let archive = root.appending(path: "my-theme.habitat-pack")
    let builder = ThemePackageBuilder(workingRoot: work)
    let suggested = try builder.suggestPalette(from: source)
    #expect(suggested == (try builder.suggestPalette(from: source)))
    #expect(allPaletteColors(suggested).allSatisfy(isHexColor))

    let manual = HabitatThemePalette(
        surface: "#101820",
        panel: "#182633",
        panelAlt: "#24384A",
        text: "#F4FAFF",
        mutedText: "#A9BAC8",
        accent: "#16C6D9",
        secondary: "#FF4F9A",
        highlight: "#FFE45C",
        attention: "#FFAA33",
        error: "#F04455"
    )
    let request = ThemePackageRequest(
        name: "../../ My CSS <script>",
        author: "Local Artist",
        sourceImageURL: source,
        palette: manual,
        category: .custom,
        styleFamily: .fantasyAdventure,
        artFocus: HabitatThemeFocalPoint(x: 0.72, y: 0.42),
        safeSide: .leading,
        backgroundStrength: 0.48,
        panelOpacity: 0.91,
        blurRadius: 12,
        density: .comfortable,
        homeMode: .framed,
        taskMode: .banner,
        chromeMaterial: .glass,
        homeStrength: 0.66,
        taskStrength: 0.34,
        sidebarOpacity: 0.78,
        headerOpacity: 0.69,
        composerOpacity: 0.92
    )

    let result = try builder.build(request, to: archive)

    #expect(result.manifest.id == ThemePackageBuilder.safeID(for: request.name))
    #expect(result.manifest.id.wholeMatch(of: /^[a-z0-9]+([.-][a-z0-9]+)*$/) != nil)
    #expect(result.manifest.colors.accent == manual.accent)
    #expect(result.manifest.theme?.styleFamily == .fantasyAdventure)
    #expect(result.manifest.theme?.homeMode == .framed)
    #expect(result.manifest.theme?.taskMode == .banner)
    #expect(result.manifest.theme?.chromeMaterial == .glass)
    #expect(result.manifest.theme?.homeStrength == 0.66)
    #expect(result.manifest.theme?.taskStrength == 0.34)
    #expect(result.manifest.theme?.sidebarOpacity == 0.78)
    #expect(result.manifest.theme?.headerOpacity == 0.69)
    #expect(result.manifest.theme?.composerOpacity == 0.92)
    #expect(result.manifest.license.spdx == "LicenseRef-Codex-Habitat-User-Content")
    #expect(try ArchiveInspector().inspect(archive).entries.map(\.path).sorted() == [
        "LICENSE", "background.jpg", "habitat.json", "preview.png",
    ])

    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let installed = try PackageInstaller(libraryRoot: library, runtimeVersion: "1.0.0")
        .install(archive)
    #expect(installed.manifest.colors == result.manifest.colors)
    #expect(try imageDimensions(installed.url.appending(path: "background.jpg")) ==
        CGSize(width: 1_600, height: 1_000))
    #expect(try imageDimensions(installed.url.appending(path: "preview.png")) ==
        CGSize(width: 800, height: 500))
    let license = try String(
        contentsOf: installed.url.appending(path: "LICENSE"),
        encoding: .utf8
    )
    #expect(license.contains("does not grant"))
    #expect(!license.contains("MIT License"))
    #expect(try directoryContents(work).isEmpty)
}

@Test
func themePackageBuilderKeepsHighEntropyBridgeArtWithinOneMiB() throws {
    let root = temporaryBuilderRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "noise.png")
    try testNoisePNG(width: 1_600, height: 1_000).write(to: source)
    let work = root.appending(path: "Work", directoryHint: .isDirectory)
    let archive = root.appending(path: "noise-theme.habitat-pack")
    let builder = ThemePackageBuilder(workingRoot: work)
    let palette = try builder.suggestPalette(from: source)
    let request = ThemePackageRequest(
        name: "Noise Test",
        author: "Local Artist",
        sourceImageURL: source,
        palette: palette,
        category: .custom,
        styleFamily: .gameCinematic,
        artFocus: HabitatThemeFocalPoint(x: 0.75, y: 0.5),
        safeSide: .leading,
        backgroundStrength: 0.42,
        panelOpacity: 0.88,
        blurRadius: 10,
        density: .comfortable,
        homeMode: .quiet,
        taskMode: .ambient,
        chromeMaterial: .tinted,
        homeStrength: 0.42,
        taskStrength: 0.19,
        sidebarOpacity: 0.88,
        headerOpacity: 0.88,
        composerOpacity: 0.88
    )

    _ = try builder.build(request, to: archive)
    let installed = try PackageInstaller(
        libraryRoot: root.appending(path: "Library", directoryHint: .isDirectory),
        runtimeVersion: "1.0.0"
    ).install(archive)
    let size = try #require(
        installed.url.appending(path: "background.jpg")
            .resourceValues(forKeys: [.fileSizeKey]).fileSize
    )
    #expect(size <= 1_048_576)
}

@Test
func themePackageBuilderRejectsUnsafeOrOversizedSourceImagesAndCleansUp() throws {
    let root = temporaryBuilderRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let work = root.appending(path: "Work", directoryHint: .isDirectory)
    let builder = ThemePackageBuilder(workingRoot: work, maxSourcePixels: 100)
    #expect(throws: ThemePackageBuildError.unsafeSourceImage) {
        try builder.suggestPalette(from: #require(URL(string: "https://example.com/theme.png")))
    }
    let validData = try testPNG(width: 11, height: 10)
    let disguised = root.appending(path: "source.txt")
    try validData.write(to: disguised)
    #expect(throws: ThemePackageBuildError.unsupportedSourceType) {
        try builder.suggestPalette(from: disguised)
    }

    let source = root.appending(path: "source.png")
    try validData.write(to: source)
    #expect(throws: ThemePackageBuildError.sourceImageTooLarge) {
        try builder.suggestPalette(from: source)
    }

    let target = root.appending(path: "target.png")
    try testPNG(width: 8, height: 8).write(to: target)
    let link = root.appending(path: "link.png")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    #expect(throws: ThemePackageBuildError.unsafeSourceImage) {
        try ThemePackageBuilder(workingRoot: work).suggestPalette(from: link)
    }
    #expect(try directoryContents(work).isEmpty)
}

private func temporaryBuilderRoot() -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeBuilder-\(UUID().uuidString)", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func directoryContents(_ url: URL) throws -> [URL] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
}

private func imageDimensions(_ url: URL) throws -> CGSize {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let properties = try #require(
        CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    )
    let width = try #require((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue)
    let height = try #require((properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue)
    return CGSize(width: width, height: height)
}

private func allPaletteColors(_ palette: HabitatThemePalette) -> [String] {
    [
        palette.surface, palette.panel, palette.panelAlt, palette.text, palette.mutedText,
        palette.accent, palette.secondary, palette.highlight, palette.attention, palette.error,
    ]
}

private func isHexColor(_ value: String) -> Bool {
    value.wholeMatch(of: /^#[0-9A-F]{6}$/) != nil
}

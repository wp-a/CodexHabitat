import CryptoKit
import Foundation
import HabitatCore
import ImageIO
import Testing
@testable import CodexHabitatApp

@Test
func bundledThemeDescriptorsExposeValidatedTokensAndPreviews() throws {
    let themes = HabitatThemeDescriptor.builtIn
    let prototypeIDs = Set(["workbench", "retro-messenger", "arcade-signal", "quiet-garden"])

    #expect(themes.count == 24)
    #expect(themes.map(\.id) == BuiltInThemeCatalog.all.map(\.id))
    #expect(Set(themes.map(\.id)).count == 24)
    #expect(themes.allSatisfy { $0.previewURL != nil && $0.backgroundURL != nil })
    #expect(Set(themes.map(\.secondaryHex)).count >= 8)
    #expect(Set(themes.map(\.category)).count >= 8)
    #expect(Set(themes.map(\.styleFamily)).count == 9)

    var backgroundHashes: Set<String> = []
    var previewHashes: Set<String> = []
    for theme in themes {
        let previewURL = try #require(theme.previewURL)
        let backgroundURL = try #require(theme.backgroundURL)
        #expect(try imageDimensions(previewURL) == CGSize(width: 800, height: 500))
        let backgroundSize = try imageDimensions(backgroundURL)
        if prototypeIDs.contains(theme.id) {
            #expect(backgroundSize == CGSize(width: 2_560, height: 1_440))
        } else {
            #expect(backgroundSize.width >= 1_600)
            #expect(backgroundSize.height >= 1_000)
        }
        #expect(try decodedImage(backgroundURL) != nil)
        #expect(try decodedImage(previewURL) != nil)
        #expect(try Data(contentsOf: backgroundURL).count <= 1_048_576)
        #expect(try Data(contentsOf: previewURL).count <= 1_048_576)
        let backgroundHash = try sha256(backgroundURL)
        #expect(backgroundHashes.insert(backgroundHash).inserted)
        #expect(previewHashes.insert(try sha256(previewURL)).inserted)
        #expect(theme.appearance.background == "background.jpg")
        #expect(try manifestBackgroundHash(themeID: theme.id) == backgroundHash)
    }
}

@Test
func bundledPrototypeManifestsPreserveTheirDistinctTreatments() throws {
    let identifiers = ["workbench", "retro-messenger", "arcade-signal", "quiet-garden"]
    let themes = try identifiers.map { identifier in
        try #require(HabitatThemeDescriptor.builtIn.first(where: { $0.id == identifier }))
    }
    let signatures = themes.map { theme in
        let appearance = theme.appearance
        return [
            appearance.resolvedHomeMode.rawValue,
            appearance.resolvedTaskMode.rawValue,
            appearance.resolvedChromeMaterial.rawValue,
            appearance.density.rawValue,
            String(format: "%.2f", appearance.resolvedHomeStrength),
            String(format: "%.2f", appearance.resolvedTaskStrength),
            String(format: "%.2f", appearance.resolvedSidebarOpacity),
            String(format: "%.2f", appearance.resolvedHeaderOpacity),
            String(format: "%.2f", appearance.resolvedComposerOpacity),
        ].joined(separator: "|")
    }

    #expect(Set(signatures).count == identifiers.count)
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

private func sha256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
}

private func decodedImage(_ url: URL) throws -> CGImage? {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

private func manifestBackgroundHash(themeID: String) throws -> String {
    let directory = "Resources/Themes/\(themeID)"
    let url = try #require(PackagedResourceLocator.url(
        forResource: "habitat",
        withExtension: "json",
        subdirectory: directory,
        packageBundleName: "CodexHabitat_CodexHabitatApp.bundle"
    ))
    let object = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    )
    let assets = try #require(object["assets"] as? [[String: Any]])
    let background = try #require(assets.first { $0["path"] as? String == "background.jpg" })
    return try #require(background["sha256"] as? String).lowercased()
}

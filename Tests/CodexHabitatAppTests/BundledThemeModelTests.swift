import CryptoKit
import Foundation
import HabitatCore
import ImageIO
import Testing
@testable import CodexHabitatApp

@Test
func bundledThemeDescriptorsExposeValidatedTokensAndPreviews() throws {
    let themes = HabitatThemeDescriptor.builtIn

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
        #expect(backgroundSize.width >= 1_600)
        #expect(backgroundSize.height >= 1_000)
        #expect(backgroundHashes.insert(try sha256(backgroundURL)).inserted)
        #expect(previewHashes.insert(try sha256(previewURL)).inserted)
        #expect(theme.appearance.background == "background.jpg")
    }
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

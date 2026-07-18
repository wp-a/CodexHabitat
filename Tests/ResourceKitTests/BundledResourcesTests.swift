import CryptoKit
import Foundation
import HabitatCore
import ImageIO
import Testing
@testable import ResourceKit

@Test
func bundledThemesUseThePublicValidatorAndLocalAccessibleAssets() throws {
    let themesRoot = repositoryRoot()
        .appending(path: "Sources/CodexHabitatApp/Resources/Themes", directoryHint: .isDirectory)
    let expectedIDs = BuiltInThemeCatalog.all.map(\.id)
    var discoveredIDs: [String] = []
    var backgroundHashes: Set<String> = []
    var previewHashes: Set<String> = []
    let prototypeIDs = Set(["workbench", "retro-messenger", "arcade-signal", "quiet-garden"])

    for id in expectedIDs {
        let directory = themesRoot.appending(path: id, directoryHint: .isDirectory)
        let manifestURL = directory.appending(path: "habitat.json")
        let data = try Data(contentsOf: manifestURL)
        let manifest = try ManifestDecoder(runtimeVersion: "1.0.0").decode(data)
        discoveredIDs.append(manifest.id)

        #expect(manifest.id == id)
        #expect(String(decoding: data, as: UTF8.self).contains("://") == false)
        #expect(contrastRatio(manifest.colors.text, manifest.colors.surface) >= 4.5)
        #expect(manifest.colors.panel != nil)
        #expect(manifest.colors.panelAlt != nil)
        #expect(manifest.colors.mutedText != nil)
        #expect(manifest.colors.secondary != nil)
        #expect(manifest.colors.highlight != nil)

        let previewURL = directory.appending(path: manifest.preview)
        let licenseURL = directory.appending(path: manifest.license.file)
        let appearance = try #require(manifest.theme)
        let backgroundURL = directory.appending(path: appearance.background)
        let backgroundAsset = try #require(manifest.assets.compactMap { resource -> HabitatImageResource? in
            guard case let .image(image) = resource, image.path == appearance.background else {
                return nil
            }
            return image
        }.first)
        #expect(try imageDimensions(previewURL) == CGSize(width: 800, height: 500))
        let expectedBackgroundSize = prototypeIDs.contains(id)
            ? CGSize(width: 2_560, height: 1_440)
            : CGSize(width: 1_600, height: 1_000)
        #expect(try imageDimensions(backgroundURL) == expectedBackgroundSize)
        #expect(try Data(contentsOf: backgroundURL).count <= 1_048_576)
        #expect(try sha256(backgroundURL) == backgroundAsset.sha256.lowercased())
        #expect(backgroundHashes.insert(try sha256(backgroundURL)).inserted)
        #expect(previewHashes.insert(try sha256(previewURL)).inserted)
        #expect(try String(contentsOf: licenseURL, encoding: .utf8).contains("MIT License"))
    }

    #expect(discoveredIDs == expectedIDs)
    #expect(Set(discoveredIDs).count == expectedIDs.count)
}

private func sha256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
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

private func contrastRatio(_ foreground: String, _ background: String) -> Double {
    let first = relativeLuminance(foreground)
    let second = relativeLuminance(background)
    return (max(first, second) + 0.05) / (min(first, second) + 0.05)
}

private func relativeLuminance(_ hex: String) -> Double {
    let value = String(hex.dropFirst())
    guard value.count >= 6, let number = Int(value.prefix(6), radix: 16) else { return 0 }
    let channels = [
        Double((number >> 16) & 0xff) / 255,
        Double((number >> 8) & 0xff) / 255,
        Double(number & 0xff) / 255,
    ].map { channel in
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
}

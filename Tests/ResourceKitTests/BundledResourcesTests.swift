import Foundation
import ImageIO
import Testing
@testable import ResourceKit

@Test
func bundledThemesUseThePublicValidatorAndLocalAccessibleAssets() throws {
    let themesRoot = repositoryRoot()
        .appending(path: "Sources/CodexHabitatApp/Resources/Themes", directoryHint: .isDirectory)
    let expectedIDs = ["workbench", "night-shift", "arcade-signal", "quiet-garden"]
    var discoveredIDs: [String] = []

    for id in expectedIDs {
        let directory = themesRoot.appending(path: id, directoryHint: .isDirectory)
        let manifestURL = directory.appending(path: "habitat.json")
        let data = try Data(contentsOf: manifestURL)
        let manifest = try ManifestDecoder(runtimeVersion: "1.0.0").decode(data)
        discoveredIDs.append(manifest.id)

        #expect(manifest.id == id)
        #expect(String(decoding: data, as: UTF8.self).contains("://") == false)
        #expect(contrastRatio(manifest.colors.text, manifest.colors.surface) >= 4.5)

        let previewURL = directory.appending(path: manifest.preview)
        let licenseURL = directory.appending(path: manifest.license.file)
        #expect(try imageDimensions(previewURL) == CGSize(width: 800, height: 500))
        #expect(try String(contentsOf: licenseURL, encoding: .utf8).contains("MIT License"))
    }

    #expect(discoveredIDs == expectedIDs)
    #expect(Set(discoveredIDs).count == expectedIDs.count)
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

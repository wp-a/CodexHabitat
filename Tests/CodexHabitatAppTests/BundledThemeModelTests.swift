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
    #expect(themes.map(\.name) == [
        "Cathedral Foundry", "Retro Messenger 2007", "Arcade Signal", "Quiet Garden",
    ])
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

@Test
func allBuiltInManifestsMatchTheCanonicalCatalog() throws {
    let descriptors = HabitatThemeDescriptor.builtIn

    #expect(descriptors.count == BuiltInThemeCatalog.all.count)
    for definition in BuiltInThemeCatalog.all {
        let descriptor = try #require(descriptors.first { $0.id == definition.id })
        #expect(catalogPaletteMismatches(definition: definition, descriptor: descriptor).isEmpty)
        #expect(catalogAppearanceMismatches(
            expected: definition.appearance(background: "background.jpg"),
            actual: descriptor.appearance
        ).isEmpty)
    }
}

@Test
func canonicalComparisonReportsAppearanceDrift() throws {
    let definition = try #require(BuiltInThemeCatalog.definition(id: "workbench"))
    let expected = definition.appearance(background: "background.jpg")
    let changed = HabitatThemeAppearance(
        category: expected.category,
        styleFamily: expected.styleFamily,
        background: expected.background,
        artFocus: expected.artFocus,
        safeSide: expected.safeSide,
        backgroundStrength: expected.backgroundStrength,
        panelOpacity: expected.panelOpacity,
        blurRadius: expected.blurRadius,
        density: expected.density,
        homeMode: expected.homeMode,
        taskMode: expected.taskMode,
        chromeMaterial: expected.chromeMaterial,
        homeStrength: expected.homeStrength,
        taskStrength: 0.11,
        sidebarOpacity: expected.sidebarOpacity,
        headerOpacity: expected.headerOpacity,
        composerOpacity: expected.composerOpacity
    )

    #expect(catalogAppearanceMismatches(expected: expected, actual: changed) == [
        "theme.taskStrength",
        "theme.resolvedTaskStrength",
    ])
}

private func catalogPaletteMismatches(
    definition: BuiltInThemeDefinition,
    descriptor: HabitatThemeDescriptor
) -> [String] {
    var mismatches: [String] = []
    appendMismatch("colors.surface", definition.palette.surface, descriptor.surfaceHex, to: &mismatches)
    appendMismatch("colors.panel", definition.palette.panel, descriptor.panelHex, to: &mismatches)
    appendMismatch("colors.panelAlt", definition.palette.panelAlt, descriptor.panelAltHex, to: &mismatches)
    appendMismatch("colors.text", definition.palette.text, descriptor.textHex, to: &mismatches)
    appendMismatch("colors.mutedText", definition.palette.mutedText, descriptor.mutedTextHex, to: &mismatches)
    appendMismatch("colors.accent", definition.palette.accent, descriptor.accentHex, to: &mismatches)
    appendMismatch("colors.secondary", definition.palette.secondary, descriptor.secondaryHex, to: &mismatches)
    appendMismatch("colors.highlight", definition.palette.highlight, descriptor.highlightHex, to: &mismatches)
    appendMismatch("colors.attention", definition.palette.attention, descriptor.attentionHex, to: &mismatches)
    appendMismatch("colors.error", definition.palette.error, descriptor.errorHex, to: &mismatches)
    return mismatches
}

private func catalogAppearanceMismatches(
    expected: HabitatThemeAppearance,
    actual: HabitatThemeAppearance
) -> [String] {
    var mismatches: [String] = []
    appendMismatch("theme.category", expected.category, actual.category, to: &mismatches)
    appendMismatch("theme.styleFamily", expected.styleFamily, actual.styleFamily, to: &mismatches)
    appendMismatch("theme.background", expected.background, actual.background, to: &mismatches)
    appendMismatch("theme.artFocus", expected.artFocus, actual.artFocus, to: &mismatches)
    appendMismatch("theme.safeSide", expected.safeSide, actual.safeSide, to: &mismatches)
    appendMismatch(
        "theme.backgroundStrength",
        expected.backgroundStrength,
        actual.backgroundStrength,
        to: &mismatches
    )
    appendMismatch("theme.panelOpacity", expected.panelOpacity, actual.panelOpacity, to: &mismatches)
    appendMismatch("theme.blurRadius", expected.blurRadius, actual.blurRadius, to: &mismatches)
    appendMismatch("theme.density", expected.density, actual.density, to: &mismatches)
    appendMismatch("theme.homeMode", expected.homeMode, actual.homeMode, to: &mismatches)
    appendMismatch("theme.taskMode", expected.taskMode, actual.taskMode, to: &mismatches)
    appendMismatch(
        "theme.chromeMaterial",
        expected.chromeMaterial,
        actual.chromeMaterial,
        to: &mismatches
    )
    appendMismatch("theme.homeStrength", expected.homeStrength, actual.homeStrength, to: &mismatches)
    appendMismatch("theme.taskStrength", expected.taskStrength, actual.taskStrength, to: &mismatches)
    appendMismatch("theme.sidebarOpacity", expected.sidebarOpacity, actual.sidebarOpacity, to: &mismatches)
    appendMismatch("theme.headerOpacity", expected.headerOpacity, actual.headerOpacity, to: &mismatches)
    appendMismatch("theme.composerOpacity", expected.composerOpacity, actual.composerOpacity, to: &mismatches)
    appendMismatch("theme.homeArtFocus", expected.homeArtFocus, actual.homeArtFocus, to: &mismatches)
    appendMismatch("theme.taskArtFocus", expected.taskArtFocus, actual.taskArtFocus, to: &mismatches)
    appendMismatch("theme.homeArtScale", expected.homeArtScale, actual.homeArtScale, to: &mismatches)
    appendMismatch("theme.taskArtScale", expected.taskArtScale, actual.taskArtScale, to: &mismatches)
    appendMismatch(
        "theme.taskSidebarOpacity",
        expected.taskSidebarOpacity,
        actual.taskSidebarOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.taskHeaderOpacity",
        expected.taskHeaderOpacity,
        actual.taskHeaderOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.homeContentOpacity",
        expected.homeContentOpacity,
        actual.homeContentOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.taskContentOpacity",
        expected.taskContentOpacity,
        actual.taskContentOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.homeContentWidth",
        expected.homeContentWidth,
        actual.homeContentWidth,
        to: &mismatches
    )
    appendMismatch(
        "theme.vignetteStrength",
        expected.vignetteStrength,
        actual.vignetteStrength,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedHomeMode",
        expected.resolvedHomeMode,
        actual.resolvedHomeMode,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedTaskMode",
        expected.resolvedTaskMode,
        actual.resolvedTaskMode,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedChromeMaterial",
        expected.resolvedChromeMaterial,
        actual.resolvedChromeMaterial,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedHomeStrength",
        expected.resolvedHomeStrength,
        actual.resolvedHomeStrength,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedTaskStrength",
        expected.resolvedTaskStrength,
        actual.resolvedTaskStrength,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedSidebarOpacity",
        expected.resolvedSidebarOpacity,
        actual.resolvedSidebarOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedHeaderOpacity",
        expected.resolvedHeaderOpacity,
        actual.resolvedHeaderOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedComposerOpacity",
        expected.resolvedComposerOpacity,
        actual.resolvedComposerOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedHomeArtFocus",
        expected.resolvedHomeArtFocus,
        actual.resolvedHomeArtFocus,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedTaskArtFocus",
        expected.resolvedTaskArtFocus,
        actual.resolvedTaskArtFocus,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedHomeArtScale",
        expected.resolvedHomeArtScale,
        actual.resolvedHomeArtScale,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedTaskArtScale",
        expected.resolvedTaskArtScale,
        actual.resolvedTaskArtScale,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedTaskSidebarOpacity",
        expected.resolvedTaskSidebarOpacity,
        actual.resolvedTaskSidebarOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedTaskHeaderOpacity",
        expected.resolvedTaskHeaderOpacity,
        actual.resolvedTaskHeaderOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedHomeContentOpacity",
        expected.resolvedHomeContentOpacity,
        actual.resolvedHomeContentOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedTaskContentOpacity",
        expected.resolvedTaskContentOpacity,
        actual.resolvedTaskContentOpacity,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedHomeContentWidth",
        expected.resolvedHomeContentWidth,
        actual.resolvedHomeContentWidth,
        to: &mismatches
    )
    appendMismatch(
        "theme.resolvedVignetteStrength",
        expected.resolvedVignetteStrength,
        actual.resolvedVignetteStrength,
        to: &mismatches
    )
    return mismatches
}

private func appendMismatch<Value: Equatable>(
    _ path: String,
    _ expected: Value,
    _ actual: Value,
    to mismatches: inout [String]
) {
    if expected != actual {
        mismatches.append(path)
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

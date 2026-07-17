import CoreGraphics
import CryptoKit
import Foundation
import HabitatCore
import ImageIO
import UniformTypeIdentifiers
import ZIPFoundation

public enum ThemePackageBuildError: Error, Equatable, Sendable {
    case unsafeSourceImage
    case unsupportedSourceType
    case invalidSourceImage
    case animatedSourceImage
    case sourceImageTooLarge
    case invalidDestination
    case imageEncodingFailed
}

public struct ThemePackageRequest: Equatable, Sendable {
    public let name: String
    public let author: String
    public let sourceImageURL: URL
    public let palette: HabitatThemePalette
    public let category: HabitatThemeCategory
    public let styleFamily: HabitatThemeStyleFamily
    public let artFocus: HabitatThemeFocalPoint
    public let safeSide: HabitatThemeSafeSide
    public let backgroundStrength: Double
    public let panelOpacity: Double
    public let blurRadius: Double
    public let density: HabitatThemeDensity

    public init(
        name: String,
        author: String,
        sourceImageURL: URL,
        palette: HabitatThemePalette,
        category: HabitatThemeCategory,
        styleFamily: HabitatThemeStyleFamily,
        artFocus: HabitatThemeFocalPoint,
        safeSide: HabitatThemeSafeSide,
        backgroundStrength: Double,
        panelOpacity: Double,
        blurRadius: Double,
        density: HabitatThemeDensity
    ) {
        self.name = name
        self.author = author
        self.sourceImageURL = sourceImageURL
        self.palette = palette
        self.category = category
        self.styleFamily = styleFamily
        self.artFocus = artFocus
        self.safeSide = safeSide
        self.backgroundStrength = backgroundStrength
        self.panelOpacity = panelOpacity
        self.blurRadius = blurRadius
        self.density = density
    }
}

public struct BuiltThemePackage: Equatable, Sendable {
    public let archiveURL: URL
    public let manifest: HabitatManifest
}

public struct ThemePackageBuilder: Sendable {
    public let workingRoot: URL
    public let runtimeVersion: String
    public let limits: PackageLimits
    public let maxSourcePixels: Int

    public init(
        workingRoot: URL = FileManager.default.temporaryDirectory.appending(
            path: "Codex Habitat Theme Studio",
            directoryHint: .isDirectory
        ),
        runtimeVersion: String = "1.0.0",
        limits: PackageLimits = PackageLimits(),
        maxSourcePixels: Int = 32_000_000
    ) {
        self.workingRoot = workingRoot
        self.runtimeVersion = runtimeVersion
        self.limits = limits
        self.maxSourcePixels = maxSourcePixels
    }

    public static func safeID(for name: String) -> String {
        let latin = name.applyingTransform(.toLatin, reverse: false) ?? name
        let folded = latin.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
        let parts = folded.lowercased().split { !$0.isASCII || !$0.isLetter && !$0.isNumber }
        var slug = parts.map(String.init).filter { !$0.isEmpty }.joined(separator: "-")
        if slug.isEmpty {
            slug = SHA256.hash(data: Data(name.utf8))
                .prefix(6)
                .map { String(format: "%02x", $0) }
                .joined()
        }
        slug = String(slug.prefix(80)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "local.theme.\(slug.isEmpty ? "untitled" : slug)"
    }

    public func suggestPalette(from sourceURL: URL) throws -> HabitatThemePalette {
        let image = try loadSourceImage(sourceURL)
        let average = try averageRGB(image)
        let luminance = 0.2126 * Double(average.r)
            + 0.7152 * Double(average.g)
            + 0.0722 * Double(average.b)
        let isLight = luminance >= 142
        let surface = isLight ? mix(average, RGB(255, 255, 255), amount: 0.72)
            : mix(average, RGB(8, 13, 20), amount: 0.58)
        let text = isLight ? RGB(20, 30, 38) : RGB(245, 250, 255)
        let accent = isLight ? mix(average, RGB(0, 118, 168), amount: 0.58)
            : mix(average, RGB(37, 220, 202), amount: 0.62)
        let secondary = RGB(accent.b, accent.r, accent.g)
        return HabitatThemePalette(
            surface: surface.hex,
            panel: mix(surface, text, amount: 0.08).hex,
            panelAlt: mix(surface, accent, amount: 0.20).hex,
            text: text.hex,
            mutedText: mix(text, surface, amount: 0.38).hex,
            accent: accent.hex,
            secondary: secondary.hex,
            highlight: "#FFE15A",
            attention: "#F5A33A",
            error: "#E5485D"
        )
    }

    public func build(
        _ request: ThemePackageRequest,
        to destination: URL
    ) throws -> BuiltThemePackage {
        let fileManager = FileManager.default
        try validateDestination(destination, fileManager: fileManager)
        let sourceImage = try loadSourceImage(request.sourceImageURL)
        try fileManager.createDirectory(
            at: workingRoot,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let transaction = workingRoot.appending(
            path: ".theme-build-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(
            at: transaction,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? fileManager.removeItem(at: transaction) }

        let backgroundURL = transaction.appending(path: "background.jpg")
        let previewURL = transaction.appending(path: "preview.png")
        let normalized = try aspectFill(sourceImage, width: 1_600, height: 1_000)
        try write(normalized, to: backgroundURL, type: .jpeg, quality: 0.84)
        let preview = try aspectFill(normalized, width: 800, height: 500)
        try write(preview, to: previewURL, type: .png, quality: nil)

        let backgroundHash = SHA256.hash(data: try Data(contentsOf: backgroundURL))
            .map { String(format: "%02x", $0) }
            .joined()
        let manifestData = try makeManifestData(request, backgroundHash: backgroundHash)
        let manifest = try ManifestDecoder(runtimeVersion: runtimeVersion).decode(manifestData)
        try manifestData.write(
            to: transaction.appending(path: "habitat.json"),
            options: [.atomic]
        )
        try Data(Self.licenseText.utf8).write(
            to: transaction.appending(path: "LICENSE"),
            options: [.atomic]
        )

        for filename in ["background.jpg", "preview.png", "habitat.json", "LICENSE"] {
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: transaction.appending(path: filename).path
            )
        }
        let archiveURL = transaction.appending(path: "theme.habitat-pack")
        let archive = try Archive(url: archiveURL, accessMode: .create)
        for filename in ["LICENSE", "background.jpg", "habitat.json", "preview.png"] {
            try archive.addEntry(
                with: filename,
                fileURL: transaction.appending(path: filename),
                compressionMethod: .deflate
            )
        }
        _ = try ArchiveInspector(limits: limits).inspect(archiveURL)

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: archiveURL)
        } else {
            try fileManager.moveItem(at: archiveURL, to: destination)
        }
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        return BuiltThemePackage(archiveURL: destination, manifest: manifest)
    }

    public func buildAndInstall(
        _ request: ThemePackageRequest,
        libraryRoot: URL,
        replacing: Bool = false
    ) throws -> InstalledPackage {
        let temporaryArchive = workingRoot.appending(
            path: ".theme-install-\(UUID().uuidString).habitat-pack"
        )
        defer { try? FileManager.default.removeItem(at: temporaryArchive) }
        _ = try build(request, to: temporaryArchive)
        return try PackageInstaller(
            libraryRoot: libraryRoot,
            runtimeVersion: runtimeVersion,
            limits: limits
        ).install(temporaryArchive, replacing: replacing)
    }

    private func loadSourceImage(_ url: URL) throws -> CGImage {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
        ])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              (values.fileSize ?? 0) <= Int(limits.maxEntryUncompressedBytes)
        else {
            throw ThemePackageBuildError.unsafeSourceImage
        }
        let extensionName = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "webp"].contains(extensionName),
              extensionName == url.pathExtension
        else {
            throw ThemePackageBuildError.unsupportedSourceType
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard signatureMatches(data, extensionName: extensionName) else {
            throw ThemePackageBuildError.unsupportedSourceType
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ThemePackageBuildError.invalidSourceImage
        }
        guard CGImageSourceGetCount(source) == 1 else {
            throw ThemePackageBuildError.animatedSourceImage
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any],
            let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
            width > 0,
            height > 0,
            width <= limits.maxImageWidth,
            height <= limits.maxImageHeight,
            width.multipliedReportingOverflow(by: height).overflow == false,
            width * height <= maxSourcePixels
        else {
            throw ThemePackageBuildError.sourceImageTooLarge
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1_600, 1_000),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ThemePackageBuildError.invalidSourceImage
        }
        return image
    }

    private func signatureMatches(_ data: Data, extensionName: String) -> Bool {
        switch extensionName {
        case "png":
            return data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case "jpg", "jpeg":
            return data.count >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF
        case "webp":
            return data.count >= 12
                && String(decoding: data[0..<4], as: UTF8.self) == "RIFF"
                && String(decoding: data[8..<12], as: UTF8.self) == "WEBP"
        default:
            return false
        }
    }

    private func validateDestination(_ url: URL, fileManager: FileManager) throws {
        guard url.pathExtension == "habitat-pack" else {
            throw ThemePackageBuildError.invalidDestination
        }
        if fileManager.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw ThemePackageBuildError.invalidDestination
            }
        }
    }

    private func aspectFill(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            throw ThemePackageBuildError.imageEncodingFailed
        }
        context.interpolationQuality = .high
        context.setFillColor(CGColor(gray: 0.08, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let scale = max(Double(width) / Double(image.width), Double(height) / Double(image.height))
        let drawnWidth = Double(image.width) * scale
        let drawnHeight = Double(image.height) * scale
        context.draw(
            image,
            in: CGRect(
                x: (Double(width) - drawnWidth) / 2,
                y: (Double(height) - drawnHeight) / 2,
                width: drawnWidth,
                height: drawnHeight
            )
        )
        guard let result = context.makeImage() else {
            throw ThemePackageBuildError.imageEncodingFailed
        }
        return result
    }

    private func write(
        _ image: CGImage,
        to url: URL,
        type: UTType,
        quality: Double?
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw ThemePackageBuildError.imageEncodingFailed
        }
        let properties = quality.map {
            [kCGImageDestinationLossyCompressionQuality: $0] as CFDictionary
        }
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw ThemePackageBuildError.imageEncodingFailed
        }
    }

    private func averageRGB(_ image: CGImage) throws -> RGB {
        let width = 16
        let height = 16
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ThemePackageBuildError.invalidSourceImage
        }
        let created = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard created else { throw ThemePackageBuildError.invalidSourceImage }
        var red = 0
        var green = 0
        var blue = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            red += Int(pixels[index])
            green += Int(pixels[index + 1])
            blue += Int(pixels[index + 2])
        }
        let count = width * height
        return RGB(red / count, green / count, blue / count)
    }

    private func mix(_ first: RGB, _ second: RGB, amount: Double) -> RGB {
        RGB(
            Int(Double(first.r) * (1 - amount) + Double(second.r) * amount),
            Int(Double(first.g) * (1 - amount) + Double(second.g) * amount),
            Int(Double(first.b) * (1 - amount) + Double(second.b) * amount)
        )
    }

    private func makeManifestData(
        _ request: ThemePackageRequest,
        backgroundHash: String
    ) throws -> Data {
        let palette = request.palette
        let object: [String: Any] = [
            "schemaVersion": 1,
            "id": Self.safeID(for: request.name),
            "name": request.name.trimmingCharacters(in: .whitespacesAndNewlines),
            "version": "1.0.0",
            "author": request.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Local User"
                : request.author.trimmingCharacters(in: .whitespacesAndNewlines),
            "license": ["spdx": "MIT", "file": "LICENSE"],
            "minimumRuntimeVersion": runtimeVersion,
            "modes": ["light", "dark"],
            "preview": "preview.png",
            "colors": [
                "surface": palette.surface,
                "panel": palette.panel,
                "panelAlt": palette.panelAlt,
                "text": palette.text,
                "mutedText": palette.mutedText,
                "accent": palette.accent,
                "secondary": palette.secondary,
                "highlight": palette.highlight,
                "attention": palette.attention,
                "error": palette.error,
            ],
            "theme": [
                "category": request.category.rawValue,
                "styleFamily": request.styleFamily.rawValue,
                "background": "background.jpg",
                "artFocus": ["x": request.artFocus.x, "y": request.artFocus.y],
                "safeSide": request.safeSide.rawValue,
                "backgroundStrength": request.backgroundStrength,
                "panelOpacity": request.panelOpacity,
                "blurRadius": request.blurRadius,
                "density": request.density.rawValue,
            ],
            "assets": [[
                "type": "image",
                "id": "theme-background",
                "path": "background.jpg",
                "sha256": backgroundHash,
                "rendering": "smooth",
            ]],
            "pets": [],
            "widgets": Self.defaultWidgets(),
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private static func defaultWidgets() -> [[String: Any]] {
        [
            [
                "id": "codex.status", "anchor": "topLeading",
                "position": ["x": 0.04, "y": 0.06],
                "configuration": ["type": "status", "showsConnectionHealth": true],
            ],
            [
                "id": "codex.tokens", "anchor": "topTrailing",
                "position": ["x": 0.96, "y": 0.24], "configuration": ["type": "tokens"],
            ],
            [
                "id": "codex.context", "anchor": "topTrailing",
                "position": ["x": 0.96, "y": 0.42], "configuration": ["type": "context"],
            ],
            [
                "id": "codex.speed", "anchor": "topTrailing",
                "position": ["x": 0.96, "y": 0.60], "configuration": ["type": "speed"],
            ],
            [
                "id": "codex.usage", "anchor": "topTrailing",
                "position": ["x": 0.96, "y": 0.78],
                "configuration": ["type": "usage", "bucket": "primary"],
            ],
        ]
    }

    private static let licenseText = """
    MIT License

    Copyright (c) 2026 Codex Habitat Contributors

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """
}

private struct RGB {
    let r: Int
    let g: Int
    let b: Int

    init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = min(max(r, 0), 255)
        self.g = min(max(g, 0), 255)
        self.b = min(max(b, 0), 255)
    }

    var hex: String {
        String(format: "#%02X%02X%02X", r, g, b)
    }
}

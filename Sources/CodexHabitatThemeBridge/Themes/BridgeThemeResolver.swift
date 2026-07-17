import CryptoKit
import Foundation
import HabitatCore
import ImageIO
import ResourceKit

enum BridgeThemeResolutionError: Error, Equatable {
    case unknownTheme
    case invalidThemeArt
}

struct BridgeThemeResolver {
    let libraryRoot: URL
    let runtimeVersion: String

    init(
        libraryRoot: URL = Self.defaultLibraryRoot(),
        runtimeVersion: String = "1.0.0"
    ) {
        self.libraryRoot = libraryRoot
        self.runtimeVersion = runtimeVersion
    }

    func resolve(id: String) throws -> BridgeTheme {
        if let builtIn = BridgeTheme.builtIn(id: id) {
            return builtIn
        }
        guard let package = InstalledPackageLibrary(
            root: libraryRoot,
            runtimeVersion: runtimeVersion
        ).currentPackages().first(where: { $0.id == id }) else {
            throw BridgeThemeResolutionError.unknownTheme
        }
        guard let appearance = package.manifest.theme,
              isSafeDirectory(package.url),
              isContained(package.url, in: libraryRoot),
              let image = declaredBackground(in: package.manifest, path: appearance.background)
        else {
            throw BridgeThemeResolutionError.invalidThemeArt
        }

        let backgroundURL = package.url.appending(path: appearance.background)
        guard isContained(backgroundURL, in: package.url),
              let values = try? backgroundURL.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
              ]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let size = values.fileSize,
              size > 0,
              size <= BridgeThemeArt.maximumBytes,
              let data = try? Data(contentsOf: backgroundURL, options: .mappedIfSafe),
              digest(data) == image.sha256.lowercased(),
              let dataURL = BridgeThemeArt.dataURL(
                data: data,
                pathExtension: backgroundURL.pathExtension
              ),
              isBoundedSingleFrameImage(data)
        else {
            throw BridgeThemeResolutionError.invalidThemeArt
        }

        let colors = package.manifest.colors
        let palette = HabitatThemePalette(
            surface: colors.surface,
            panel: colors.panel ?? colors.surface,
            panelAlt: colors.panelAlt ?? colors.accent,
            text: colors.text,
            mutedText: colors.mutedText ?? colors.text,
            accent: colors.accent,
            secondary: colors.secondary ?? colors.attention,
            highlight: colors.highlight ?? colors.accent,
            attention: colors.attention,
            error: colors.error
        )
        return BridgeTheme(
            tokens: BridgeThemeTokens(palette: palette),
            appearance: BridgeThemeAppearance(appearance),
            artBlobURL: nil,
            artDataURL: dataURL
        )
    }

    static func defaultLibraryRoot(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let configured = environment["CODEX_HABITAT_HOME"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
                .appending(path: "Library", directoryHint: .isDirectory)
        }
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return applicationSupport
            .appending(path: "Codex Habitat", directoryHint: .isDirectory)
            .appending(path: "Library", directoryHint: .isDirectory)
    }

    private func declaredBackground(
        in manifest: HabitatManifest,
        path: String
    ) -> HabitatImageResource? {
        manifest.assets.compactMap { resource -> HabitatImageResource? in
            guard case let .image(image) = resource, image.path == path else { return nil }
            return image
        }.first
    }

    private func isBoundedSingleFrameImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        else {
            return false
        }
        return (1...8_192).contains(width) && (1...8_192).contains(height)
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func isSafeDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey,
        ]) else {
            return false
        }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func isContained(_ candidate: URL, in root: URL) -> Bool {
        candidate.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/")
    }
}

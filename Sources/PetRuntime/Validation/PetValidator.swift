import Foundation
import ImageIO

public struct PetValidator {
    private enum Limits {
        static let manifestBytes: Int = 256 * 1_024
        static let identifierBytes = 128
        static let displayNameBytes = 256
        static let descriptionBytes = 4_096
        static let spritesheetPathBytes = 1_024
        static let spritesheetBytes: Int = 16 * 1_024 * 1_024
        static let imageWidth = 8_192
        static let imageHeight = 8_192
        static let imagePixels = 32_000_000
        static let imageTypes: Set<String> = [
            "org.webmproject.webp",
            "public.jpeg",
            "public.png",
        ]
    }

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validate(directory: URL) -> PetLibraryEntry {
        let manifestURL = directory.appending(path: "pet.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return invalid(directory, issue: .manifestMissing)
        }
        guard isRegularNonSymlinkFile(manifestURL),
              fileSize(of: manifestURL).map({ $0 <= Limits.manifestBytes }) == true
        else {
            return invalid(directory, issue: .manifestUnreadable)
        }

        let manifest: PetManifest
        do {
            manifest = try JSONDecoder().decode(
                PetManifest.self,
                from: Data(contentsOf: manifestURL, options: .mappedIfSafe)
            )
        } catch {
            return invalid(directory, issue: .manifestUnreadable)
        }

        guard manifest.id.utf8.count <= Limits.identifierBytes,
              isValidIdentifier(manifest.id)
        else {
            return invalid(directory, manifest: manifest, issue: .invalidIdentifier)
        }
        guard manifest.displayName.utf8.count <= Limits.displayNameBytes,
              manifest.description.utf8.count <= Limits.descriptionBytes,
              !containsControlCharacters(manifest.displayName),
              !containsControlCharacters(manifest.description)
        else {
            return invalid(directory, manifest: manifest, issue: .manifestUnreadable)
        }
        let rows: Int
        switch manifest.effectiveSpriteVersion {
        case 1:
            rows = 9
        case 2:
            rows = 11
        default:
            return invalid(directory, manifest: manifest, issue: .unsupportedSpriteVersion)
        }

        guard let spritesheetURL = containedSpritesheetURL(
            path: manifest.spritesheetPath,
            directory: directory
        ) else {
            return invalid(
                directory,
                manifest: manifest,
                issue: .spritesheetPathEscapesPackage
            )
        }
        guard fileManager.fileExists(atPath: spritesheetURL.path) else {
            return invalid(
                directory,
                manifest: manifest,
                spritesheetURL: spritesheetURL,
                issue: .spritesheetMissing
            )
        }
        guard isRegularNonSymlinkFile(spritesheetURL),
              fileSize(of: spritesheetURL).map({ $0 <= Limits.spritesheetBytes }) == true
        else {
            return invalid(
                directory,
                manifest: manifest,
                spritesheetURL: spritesheetURL,
                issue: .spritesheetUnreadable
            )
        }
        let resolvedRoot = directory.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard spritesheetURL.resolvingSymlinksInPath().standardizedFileURL.path
            .hasPrefix(resolvedRoot)
        else {
            return invalid(
                directory,
                manifest: manifest,
                spritesheetURL: spritesheetURL,
                issue: .spritesheetPathEscapesPackage
            )
        }
        guard let dimensions = imageDimensions(at: spritesheetURL) else {
            return invalid(
                directory,
                manifest: manifest,
                spritesheetURL: spritesheetURL,
                issue: .spritesheetUnreadable
            )
        }
        guard dimensions.width > 0,
              dimensions.height > 0,
              dimensions.width <= Limits.imageWidth,
              dimensions.height <= Limits.imageHeight,
              dimensions.pixelCount <= Limits.imagePixels,
              dimensions.width.isMultiple(of: 8),
              dimensions.height.isMultiple(of: rows)
        else {
            return invalid(
                directory,
                manifest: manifest,
                spritesheetURL: spritesheetURL,
                issue: .invalidSpritesheetDimensions
            )
        }

        return PetLibraryEntry(
            packageURL: directory,
            manifest: manifest,
            spritesheetURL: spritesheetURL,
            atlas: PetAtlasMetadata(
                pixelWidth: dimensions.width,
                pixelHeight: dimensions.height,
                columns: 8,
                rows: rows
            ),
            status: .valid
        )
    }

    private func isValidIdentifier(_ id: String) -> Bool {
        guard let expression = try? Regex("^[a-z0-9][a-z0-9-]*$") else { return false }
        return id.wholeMatch(of: expression) != nil
    }

    private func containedSpritesheetURL(path: String, directory: URL) -> URL? {
        guard !path.isEmpty,
              path.utf8.count <= Limits.spritesheetPathBytes,
              !NSString(string: path).isAbsolutePath,
              !containsControlCharacters(path),
              path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({
                  !$0.isEmpty && $0 != "." && $0 != ".."
              })
        else {
            return nil
        }
        let rootPath = NSString(string: directory.path).standardizingPath
        let candidatePath = NSString(
            string: NSString(string: rootPath).appendingPathComponent(path)
        ).standardizingPath
        guard candidatePath.hasPrefix(rootPath + "/") else { return nil }
        return URL(fileURLWithPath: candidatePath)
    }

    private func imageDimensions(at url: URL) -> (width: Int, height: Int, pixelCount: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sourceType = CGImageSourceGetType(source),
              Limits.imageTypes.contains(sourceType as String),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0
        else {
            return nil
        }
        let pixels = width.multipliedReportingOverflow(by: height)
        guard !pixels.overflow else { return nil }
        return (width, height, pixels.partialValue)
    }

    private func containsControlCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    private func isRegularNonSymlinkFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        ) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private func fileSize(of url: URL) -> Int? {
        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    private func invalid(
        _ directory: URL,
        manifest: PetManifest? = nil,
        spritesheetURL: URL? = nil,
        issue: PetValidationIssue
    ) -> PetLibraryEntry {
        PetLibraryEntry(
            packageURL: directory,
            manifest: manifest,
            spritesheetURL: spritesheetURL,
            atlas: nil,
            status: .invalid(issue)
        )
    }
}

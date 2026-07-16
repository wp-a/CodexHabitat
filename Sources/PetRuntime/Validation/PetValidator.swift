import Foundation
import ImageIO

public struct PetValidator {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validate(directory: URL) -> PetLibraryEntry {
        let manifestURL = directory.appending(path: "pet.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return invalid(directory, issue: .manifestMissing)
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

        guard isValidIdentifier(manifest.id) else {
            return invalid(directory, manifest: manifest, issue: .invalidIdentifier)
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
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: spritesheetURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            return invalid(
                directory,
                manifest: manifest,
                spritesheetURL: spritesheetURL,
                issue: .spritesheetMissing
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
        guard !path.isEmpty, !NSString(string: path).isAbsolutePath else { return nil }
        let rootPath = NSString(string: directory.path).standardizingPath
        let candidatePath = NSString(
            string: NSString(string: rootPath).appendingPathComponent(path)
        ).standardizingPath
        guard candidatePath.hasPrefix(rootPath + "/") else { return nil }
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let candidate = URL(fileURLWithPath: candidatePath)
        if fileManager.fileExists(atPath: candidate.path) {
            let resolvedRoot = root.resolvingSymlinksInPath()
            let resolvedCandidate = candidate.resolvingSymlinksInPath()
            guard resolvedCandidate.path.hasPrefix(resolvedRoot.path + "/") else { return nil }
        }
        return candidate
    }

    private func imageDimensions(at url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        else {
            return nil
        }
        return (width, height)
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

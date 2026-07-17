import CryptoKit
import CoreGraphics
import Darwin
import Foundation
import ImageIO
import ZIPFoundation

public struct InstalledPackage: Equatable, Sendable {
    public let id: String
    public let version: String
    public let url: URL
    public let manifest: HabitatManifest
}

public enum PackageInstallationError: Error, Equatable, Sendable {
    case alreadyInstalled
    case manifestTooLarge
    case missingDeclaredFile(String)
    case undeclaredFile(String)
    case hashMismatch(String)
    case invalidImage(String)
    case invalidFont(String)
    case imageDimensionsExceeded(String)
    case checksumMismatch(String)
    case unsafeExtractionPath(String)
    case contentIDMismatch(expected: String, actual: String)
}

public struct PackageInstaller {
    public let libraryRoot: URL
    public let runtimeVersion: String
    public let limits: PackageLimits

    private let fileManager: FileManager

    public init(
        libraryRoot: URL,
        runtimeVersion: String,
        limits: PackageLimits = PackageLimits(),
        fileManager: FileManager = .default
    ) {
        self.libraryRoot = libraryRoot
        self.runtimeVersion = runtimeVersion
        self.limits = limits
        self.fileManager = fileManager
    }

    public func install(
        _ archiveURL: URL,
        replacing: Bool = false,
        expectedID: String? = nil
    ) throws -> InstalledPackage {
        try prepareLibraryRoot()
        let transactionURL = libraryRoot.appending(
            path: ".install-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(
            at: transactionURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer {
            if fileManager.fileExists(atPath: transactionURL.path) {
                try? fileManager.removeItem(at: transactionURL)
            }
        }

        let archiveSnapshotURL = transactionURL.appending(path: "source.habitat-pack")
        try copyArchiveSnapshot(from: archiveURL, to: archiveSnapshotURL)
        let inspection = try ArchiveInspector(limits: limits).inspect(archiveSnapshotURL)
        let stagingURL = transactionURL.appending(path: "payload", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: stagingURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try extract(inspection, to: stagingURL)
        let manifest = try loadManifest(from: stagingURL)
        if let expectedID, manifest.id != expectedID {
            throw PackageInstallationError.contentIDMismatch(
                expected: expectedID,
                actual: manifest.id
            )
        }
        try validateContents(manifest, inspection: inspection, stagingURL: stagingURL)
        try synchronizeTree(at: stagingURL)

        let packageRoot = libraryRoot.appending(path: manifest.id, directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: packageRoot,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let destination = packageRoot.appending(
            path: manifest.version,
            directoryHint: .isDirectory
        )
        let destinationExists = fileManager.fileExists(atPath: destination.path)
        guard replacing || !destinationExists else {
            throw PackageInstallationError.alreadyInstalled
        }

        if destinationExists {
            _ = try fileManager.replaceItemAt(
                destination,
                withItemAt: stagingURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly]
            )
        } else {
            try fileManager.moveItem(at: stagingURL, to: destination)
        }
        try synchronizeDirectory(at: packageRoot)
        return InstalledPackage(
            id: manifest.id,
            version: manifest.version,
            url: destination,
            manifest: manifest
        )
    }

    private func prepareLibraryRoot() throws {
        try fileManager.createDirectory(
            at: libraryRoot,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: libraryRoot.path)
    }

    private func copyArchiveSnapshot(from source: URL, to destination: URL) throws {
        let sourceDescriptor = source.withUnsafeFileSystemRepresentation { path in
            path.map { Darwin.open($0, O_RDONLY | O_NOFOLLOW) } ?? -1
        }
        guard sourceDescriptor >= 0 else {
            if errno == ELOOP {
                throw ArchiveInspectionError.archiveSymlinkNotAllowed
            }
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        let input = FileHandle(fileDescriptor: sourceDescriptor, closeOnDealloc: true)
        defer { try? input.close() }

        guard fileManager.createFile(
            atPath: destination.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destination.path])
        }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        var copiedBytes: UInt64 = 0
        while let data = try input.read(upToCount: 64 * 1024), !data.isEmpty {
            let (nextSize, overflow) = copiedBytes.addingReportingOverflow(UInt64(data.count))
            guard !overflow, nextSize <= limits.maxArchiveBytes else {
                throw ArchiveInspectionError.archiveTooLarge
            }
            try output.write(contentsOf: data)
            copiedBytes = nextSize
        }
        try output.synchronize()
    }

    private func extract(_ inspection: InspectedArchive, to stagingURL: URL) throws {
        let archive = try Archive(url: inspection.archiveURL, accessMode: .read)
        let inspectedByPath = Dictionary(uniqueKeysWithValues: inspection.entries.map { ($0.path, $0) })
        for entry in archive {
            guard let metadata = inspectedByPath[entry.path] else {
                throw PackageInstallationError.unsafeExtractionPath(entry.path)
            }
            let destination = stagingURL.appending(path: entry.path)
            guard isContained(destination, in: stagingURL) else {
                throw PackageInstallationError.unsafeExtractionPath(entry.path)
            }
            let checksum = try archive.extract(
                entry,
                to: destination,
                bufferSize: 16 * 1024,
                skipCRC32: false,
                allowUncontainedSymlinks: false
            )
            guard checksum == metadata.checksum else {
                throw PackageInstallationError.checksumMismatch(entry.path)
            }
            let permissions: Int = metadata.type == .directory ? 0o700 : 0o600
            try fileManager.setAttributes(
                [.posixPermissions: permissions],
                ofItemAtPath: destination.path
            )
        }
    }

    private func loadManifest(from stagingURL: URL) throws -> HabitatManifest {
        let manifestURL = stagingURL.appending(path: "habitat.json")
        let attributes = try fileManager.attributesOfItem(atPath: manifestURL.path)
        let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        guard size <= limits.maxManifestBytes else {
            throw PackageInstallationError.manifestTooLarge
        }
        let data = try Data(contentsOf: manifestURL, options: .mappedIfSafe)
        return try ManifestDecoder(runtimeVersion: runtimeVersion).decode(data)
    }

    private func validateContents(
        _ manifest: HabitatManifest,
        inspection: InspectedArchive,
        stagingURL: URL
    ) throws {
        let actualFiles = Set(inspection.entries.compactMap { entry in
            entry.type == .file ? entry.path : nil
        })
        var declaredFiles: Set<String> = [
            "habitat.json", manifest.preview, manifest.license.file,
        ]
        var resources: [(path: String, sha256: String)] = []
        var fontPaths: Set<String> = []
        for resource in manifest.assets {
            switch resource {
            case let .image(image):
                declaredFiles.insert(image.path)
                resources.append((image.path, image.sha256))
            case let .font(font):
                declaredFiles.insert(font.path)
                resources.append((font.path, font.sha256))
                fontPaths.insert(font.path)
            }
        }

        for path in declaredFiles {
            guard actualFiles.contains(path), isRegularFile(stagingURL.appending(path: path)) else {
                throw PackageInstallationError.missingDeclaredFile(path)
            }
        }
        for path in actualFiles where !declaredFiles.contains(path) {
            let belongsToPet = manifest.pets.contains { pet in
                path.hasPrefix(pet.path + "/")
            }
            guard belongsToPet else {
                throw PackageInstallationError.undeclaredFile(path)
            }
        }
        for pet in manifest.pets {
            let petURL = stagingURL.appending(path: pet.path, directoryHint: .isDirectory)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: petURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                throw PackageInstallationError.missingDeclaredFile(pet.path)
            }
        }

        for resource in resources {
            let url = stagingURL.appending(path: resource.path)
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == resource.sha256.lowercased() else {
                throw PackageInstallationError.hashMismatch(resource.path)
            }
        }
        for path in actualFiles where isImage(path) {
            try validateImage(at: stagingURL.appending(path: path), relativePath: path)
        }
        for path in fontPaths {
            try validateFont(at: stagingURL.appending(path: path), relativePath: path)
        }
    }

    private func validateImage(at url: URL, relativePath: String) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0
        else {
            throw PackageInstallationError.invalidImage(relativePath)
        }
        let pixels = width.multipliedReportingOverflow(by: height)
        guard width <= limits.maxImageWidth,
              height <= limits.maxImageHeight,
              !pixels.overflow,
              pixels.partialValue <= limits.maxImagePixels
        else {
            throw PackageInstallationError.imageDimensionsExceeded(relativePath)
        }
    }

    private func validateFont(at url: URL, relativePath: String) throws {
        guard let provider = CGDataProvider(url: url as CFURL),
              CGFont(provider) != nil
        else {
            throw PackageInstallationError.invalidFont(relativePath)
        }
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]))
            .map { $0.isRegularFile == true && $0.isSymbolicLink != true } ?? false
    }

    private func isContained(_ candidate: URL, in root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path + "/"
        return candidate.standardizedFileURL.path.hasPrefix(rootPath)
    }

    private func isImage(_ path: String) -> Bool {
        ["png", "jpg", "jpeg", "webp"].contains(URL(fileURLWithPath: path).pathExtension)
    }

    private func synchronizeTree(at root: URL) throws {
        if let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    try synchronizeFile(at: url)
                }
            }
        }
        try synchronizeDirectory(at: root)
    }

    private func synchronizeFile(at url: URL) throws {
        try synchronizeDescriptor(at: url)
    }

    private func synchronizeDirectory(at url: URL) throws {
        try synchronizeDescriptor(at: url)
    }

    private func synchronizeDescriptor(at url: URL) throws {
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            path.map { Darwin.open($0, O_RDONLY) } ?? -1
        }
        guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }
}

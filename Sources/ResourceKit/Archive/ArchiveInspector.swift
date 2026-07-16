import Foundation
import ZIPFoundation

public enum InspectedEntryType: Equatable, Sendable {
    case file
    case directory
}

public struct InspectedArchiveEntry: Equatable, Sendable {
    public let path: String
    public let type: InspectedEntryType
    public let compressedSize: UInt64
    public let uncompressedSize: UInt64
    public let checksum: UInt32
}

public struct InspectedArchive: Equatable, Sendable {
    public let archiveURL: URL
    public let entries: [InspectedArchiveEntry]
    public let totalCompressedBytes: UInt64
    public let totalUncompressedBytes: UInt64
}

public enum ArchiveInspectionError: Error, Equatable, Sendable {
    case archiveTooLarge
    case archiveSymlinkNotAllowed
    case fileCountExceeded
    case totalCompressedSizeExceeded
    case totalUncompressedSizeExceeded
    case entryTooLarge(String)
    case compressionRatioExceeded(String)
    case unsafePath(String)
    case symlinkNotAllowed(String)
    case duplicatePath(String)
    case unsupportedFile(String)
    case executablePermissions(String)
    case missingManifest
}

public struct ArchiveInspector: Sendable {
    public let limits: PackageLimits

    public init(limits: PackageLimits = PackageLimits()) {
        self.limits = limits
    }

    public func inspect(_ archiveURL: URL) throws -> InspectedArchive {
        let resourceValues = try archiveURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard resourceValues.isSymbolicLink != true else {
            throw ArchiveInspectionError.archiveSymlinkNotAllowed
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
        let archiveBytes = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        guard archiveBytes <= limits.maxArchiveBytes else {
            throw ArchiveInspectionError.archiveTooLarge
        }

        let archive = try Archive(url: archiveURL, accessMode: .read)
        var entries: [InspectedArchiveEntry] = []
        var normalizedPaths: Set<String> = []
        var totalCompressedBytes: UInt64 = 0
        var totalUncompressedBytes: UInt64 = 0

        for entry in archive {
            guard entries.count < limits.maxFileCount else {
                throw ArchiveInspectionError.fileCountExceeded
            }
            let path = entry.path
            let pathForValidation = entry.type == .directory && path.hasSuffix("/")
                ? String(path.dropLast())
                : path
            try validatePath(pathForValidation)

            let normalized = normalizedPath(pathForValidation)
            guard normalizedPaths.insert(normalized).inserted else {
                throw ArchiveInspectionError.duplicatePath(pathForValidation)
            }

            let type: InspectedEntryType
            switch entry.type {
            case .file:
                type = .file
                try validateFile(pathForValidation, attributes: entry.fileAttributes)
            case .directory:
                type = .directory
            case .symlink:
                throw ArchiveInspectionError.symlinkNotAllowed(pathForValidation)
            }

            guard entry.uncompressedSize <= limits.maxEntryUncompressedBytes else {
                throw ArchiveInspectionError.entryTooLarge(pathForValidation)
            }
            if entry.uncompressedSize > 0 {
                guard entry.compressedSize > 0,
                      Double(entry.uncompressedSize) / Double(entry.compressedSize)
                        <= limits.maxCompressionRatio
                else {
                    throw ArchiveInspectionError.compressionRatioExceeded(pathForValidation)
                }
            }

            let (nextCompressed, compressedOverflow) = totalCompressedBytes.addingReportingOverflow(
                entry.compressedSize
            )
            guard !compressedOverflow, nextCompressed <= limits.maxCompressedBytes else {
                throw ArchiveInspectionError.totalCompressedSizeExceeded
            }
            totalCompressedBytes = nextCompressed

            let (nextUncompressed, uncompressedOverflow) = totalUncompressedBytes.addingReportingOverflow(
                entry.uncompressedSize
            )
            guard !uncompressedOverflow, nextUncompressed <= limits.maxUncompressedBytes else {
                throw ArchiveInspectionError.totalUncompressedSizeExceeded
            }
            totalUncompressedBytes = nextUncompressed

            entries.append(InspectedArchiveEntry(
                path: path,
                type: type,
                compressedSize: entry.compressedSize,
                uncompressedSize: entry.uncompressedSize,
                checksum: entry.checksum
            ))
        }

        guard entries.contains(where: { $0.path == "habitat.json" && $0.type == .file }) else {
            throw ArchiveInspectionError.missingManifest
        }
        return InspectedArchive(
            archiveURL: archiveURL,
            entries: entries,
            totalCompressedBytes: totalCompressedBytes,
            totalUncompressedBytes: totalUncompressedBytes
        )
    }

    private func validatePath(_ path: String) throws {
        guard !path.isEmpty,
              path.count <= 512,
              !path.hasPrefix("/"),
              !path.hasPrefix("~"),
              !path.contains("\\"),
              !path.contains(":"),
              !path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            throw ArchiveInspectionError.unsafePath(path)
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".." && !$0.hasPrefix(".")
        }) else {
            throw ArchiveInspectionError.unsafePath(path)
        }
    }

    private func validateFile(
        _ path: String,
        attributes: [FileAttributeKey: Any]
    ) throws {
        let extensionName = URL(fileURLWithPath: path).pathExtension
        let filename = URL(fileURLWithPath: path).lastPathComponent.uppercased()
        let allowedExtensions: Set<String> = [
            "json", "png", "jpg", "jpeg", "webp", "otf", "ttf", "woff2", "txt", "md",
        ]
        let isExtensionlessLegalText = extensionName.isEmpty
            && (filename == "LICENSE" || filename == "NOTICE")
        guard isExtensionlessLegalText
            || (extensionName == extensionName.lowercased() && allowedExtensions.contains(extensionName))
        else {
            throw ArchiveInspectionError.unsupportedFile(path)
        }

        let permissions = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        guard permissions & 0o111 == 0 else {
            throw ArchiveInspectionError.executablePermissions(path)
        }
    }

    private func normalizedPath(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }
}

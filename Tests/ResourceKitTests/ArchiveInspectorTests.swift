import Foundation
import Testing
import ZIPFoundation
@testable import ResourceKit

@Test
func boundedStaticArchivePassesMetadataInspection() throws {
    let archiveURL = try makeTestArchive([
        TestArchiveEntry(path: "habitat.json", data: Data("{}".utf8)),
        TestArchiveEntry(path: "preview.png", data: try testPNG()),
        TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
    ])
    defer { try? FileManager.default.removeItem(at: archiveURL) }

    let inspection = try ArchiveInspector().inspect(archiveURL)

    #expect(inspection.entries.count == 3)
    #expect(inspection.entries.map(\.path).contains("habitat.json"))
}

@Test(arguments: [
    "../escape.txt",
    "/absolute.txt",
    "safe/../../escape.txt",
    "folder\\escape.txt",
])
func unsafeArchivePathsAreRejected(path: String) throws {
    let archiveURL = try makeTestArchive(baseEntries() + [
        TestArchiveEntry(path: path, data: Data("bad".utf8)),
    ])
    defer { try? FileManager.default.removeItem(at: archiveURL) }

    #expect(throws: ArchiveInspectionError.unsafePath(path)) {
        try ArchiveInspector().inspect(archiveURL)
    }
}

@Test
func symlinksAndDuplicateNormalizedPathsAreRejected() throws {
    let symlinkURL = try makeTestArchive(baseEntries() + [
        TestArchiveEntry(path: "link", type: .symlink, data: Data("../outside".utf8)),
    ])
    defer { try? FileManager.default.removeItem(at: symlinkURL) }
    #expect(throws: ArchiveInspectionError.symlinkNotAllowed("link")) {
        try ArchiveInspector().inspect(symlinkURL)
    }

    let duplicateURL = try makeTestArchive(baseEntries() + [
        TestArchiveEntry(path: "Artwork/Icon.png", data: try testPNG()),
        TestArchiveEntry(path: "artwork/icon.png", data: try testPNG()),
    ])
    defer { try? FileManager.default.removeItem(at: duplicateURL) }
    #expect(throws: ArchiveInspectionError.duplicatePath("artwork/icon.png")) {
        try ArchiveInspector().inspect(duplicateURL)
    }
}

@Test
func archiveFileSymlinkIsRejectedBeforeReadingItsTarget() throws {
    let targetURL = try makeTestArchive(baseEntries())
    let linkURL = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatArchiveLink-\(UUID().uuidString).habitat-pack")
    defer {
        try? FileManager.default.removeItem(at: linkURL)
        try? FileManager.default.removeItem(at: targetURL)
    }
    try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

    #expect(throws: ArchiveInspectionError.archiveSymlinkNotAllowed) {
        try ArchiveInspector().inspect(linkURL)
    }
}

@Test(arguments: ["scripts/run.sh", "index.html", "fonts/remote.css", "vector.svg"])
func activeOrExecutableContentIsRejected(path: String) throws {
    let archiveURL = try makeTestArchive(baseEntries() + [
        TestArchiveEntry(path: path, data: Data("https://example.com/font".utf8)),
    ])
    defer { try? FileManager.default.removeItem(at: archiveURL) }

    #expect(throws: ArchiveInspectionError.unsupportedFile(path)) {
        try ArchiveInspector().inspect(archiveURL)
    }
}

@Test
func countSizeAndCompressionRatioLimitsAreEnforcedBeforeExtraction() throws {
    let countURL = try makeTestArchive(baseEntries() + [
        TestArchiveEntry(path: "one.txt"),
        TestArchiveEntry(path: "two.txt"),
    ])
    defer { try? FileManager.default.removeItem(at: countURL) }
    #expect(throws: ArchiveInspectionError.fileCountExceeded) {
        try ArchiveInspector(limits: PackageLimits(maxFileCount: 3)).inspect(countURL)
    }

    let sizeURL = try makeTestArchive(baseEntries() + [
        TestArchiveEntry(path: "large.txt", data: Data(repeating: 1, count: 128)),
    ])
    defer { try? FileManager.default.removeItem(at: sizeURL) }
    #expect(throws: ArchiveInspectionError.entryTooLarge("large.txt")) {
        try ArchiveInspector(limits: PackageLimits(maxEntryUncompressedBytes: 64)).inspect(sizeURL)
    }

    let totalSizeURL = try makeTestArchive(baseEntries() + [
        TestArchiveEntry(path: "one.txt", data: Data(repeating: 1, count: 40)),
        TestArchiveEntry(path: "two.txt", data: Data(repeating: 2, count: 40)),
    ])
    defer { try? FileManager.default.removeItem(at: totalSizeURL) }
    #expect(throws: ArchiveInspectionError.totalUncompressedSizeExceeded) {
        try ArchiveInspector(limits: PackageLimits(maxUncompressedBytes: 64)).inspect(totalSizeURL)
    }

    let ratioURL = try makeTestArchive(baseEntries() + [
        TestArchiveEntry(
            path: "compressed.txt",
            data: Data(repeating: 0, count: 64 * 1024),
            compression: .deflate
        ),
    ])
    defer { try? FileManager.default.removeItem(at: ratioURL) }
    #expect(throws: ArchiveInspectionError.compressionRatioExceeded("compressed.txt")) {
        try ArchiveInspector(limits: PackageLimits(maxCompressionRatio: 2)).inspect(ratioURL)
    }
}

@Test
func executablePermissionBitsAreRejectedEvenForAllowedExtensions() throws {
    let archiveURL = try makeTestArchive(baseEntries() + [
        TestArchiveEntry(
            path: "notes.txt",
            data: Data("text".utf8),
            permissions: 0o755
        ),
    ])
    defer { try? FileManager.default.removeItem(at: archiveURL) }

    #expect(throws: ArchiveInspectionError.executablePermissions("notes.txt")) {
        try ArchiveInspector().inspect(archiveURL)
    }
}

private func baseEntries() -> [TestArchiveEntry] {
    [
        TestArchiveEntry(path: "habitat.json", data: Data("{}".utf8)),
        TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
    ]
}

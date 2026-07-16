import CryptoKit
import Foundation
import Testing
@testable import ResourceKit

@Test
func validPackInstallsIntoVersionedDirectoryWithoutOverwriting() throws {
    try withTemporaryLibrary { library in
        let archiveURL = try validPackArchive(licenseText: "first")
        defer { try? FileManager.default.removeItem(at: archiveURL) }
        let installer = PackageInstaller(libraryRoot: library, runtimeVersion: "1.0.0")

        let installed = try installer.install(archiveURL)

        #expect(installed.id == "studio.example.safe-pack")
        #expect(installed.version == "1.0.0")
        #expect(FileManager.default.fileExists(atPath: installed.url.appending(path: "preview.png").path))
        #expect(throws: PackageInstallationError.alreadyInstalled) {
            try installer.install(archiveURL)
        }
    }
}

@Test
func explicitReplacementAtomicallyPublishesTheNewPack() throws {
    try withTemporaryLibrary { library in
        let firstURL = try validPackArchive(licenseText: "first")
        let secondURL = try validPackArchive(licenseText: "second")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let installer = PackageInstaller(libraryRoot: library, runtimeVersion: "1.0.0")
        _ = try installer.install(firstURL)

        let installed = try installer.install(secondURL, replacing: true)

        let license = try String(contentsOf: installed.url.appending(path: "LICENSE"), encoding: .utf8)
        #expect(license == "second")
        #expect(try stagingDirectories(in: library).isEmpty)
    }
}

@Test
func hashMismatchAndUndeclaredFilesLeaveNoPublishedPackage() throws {
    try withTemporaryLibrary { library in
        let image = try testPNG()
        let assets: [[String: Any]] = [[
            "type": "image",
            "id": "art",
            "path": "artwork/art.png",
            "sha256": String(repeating: "0", count: 64),
            "rendering": "smooth",
        ]]
        let hashURL = try makeTestArchive([
            TestArchiveEntry(path: "habitat.json", data: try minimalManifestData(assets: assets)),
            TestArchiveEntry(path: "preview.png", data: image),
            TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
            TestArchiveEntry(path: "artwork/art.png", data: image),
        ])
        defer { try? FileManager.default.removeItem(at: hashURL) }
        let installer = PackageInstaller(libraryRoot: library, runtimeVersion: "1.0.0")

        #expect(throws: PackageInstallationError.hashMismatch("artwork/art.png")) {
            try installer.install(hashURL)
        }

        let undeclaredURL = try makeTestArchive([
            TestArchiveEntry(path: "habitat.json", data: try minimalManifestData()),
            TestArchiveEntry(path: "preview.png", data: image),
            TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
            TestArchiveEntry(path: "extra.txt", data: Data("not declared".utf8)),
        ])
        defer { try? FileManager.default.removeItem(at: undeclaredURL) }
        #expect(throws: PackageInstallationError.undeclaredFile("extra.txt")) {
            try installer.install(undeclaredURL)
        }

        #expect(try publishedPackageDirectories(in: library).isEmpty)
        #expect(try stagingDirectories(in: library).isEmpty)
    }
}

@Test
func excessiveImageCanvasIsRejectedBeforePublication() throws {
    try withTemporaryLibrary { library in
        let archiveURL = try makeTestArchive([
            TestArchiveEntry(path: "habitat.json", data: try minimalManifestData()),
            TestArchiveEntry(path: "preview.png", data: try testPNG(width: 11, height: 1)),
            TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
        ])
        defer { try? FileManager.default.removeItem(at: archiveURL) }
        let installer = PackageInstaller(
            libraryRoot: library,
            runtimeVersion: "1.0.0",
            limits: PackageLimits(maxImageWidth: 10)
        )

        #expect(throws: PackageInstallationError.imageDimensionsExceeded("preview.png")) {
            try installer.install(archiveURL)
        }
        #expect(try publishedPackageDirectories(in: library).isEmpty)
    }
}

@Test
func malformedFontWithAValidHashIsRejectedBeforePublication() throws {
    try withTemporaryLibrary { library in
        let fontData = Data("not a font".utf8)
        let digest = SHA256.hash(data: fontData).map { String(format: "%02x", $0) }.joined()
        let assets: [[String: Any]] = [[
            "type": "font",
            "id": "font",
            "path": "fonts/font.otf",
            "sha256": digest,
        ]]
        let archiveURL = try makeTestArchive([
            TestArchiveEntry(path: "habitat.json", data: try minimalManifestData(assets: assets)),
            TestArchiveEntry(path: "preview.png", data: try testPNG()),
            TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
            TestArchiveEntry(path: "fonts/font.otf", data: fontData),
        ])
        defer { try? FileManager.default.removeItem(at: archiveURL) }
        let installer = PackageInstaller(libraryRoot: library, runtimeVersion: "1.0.0")

        #expect(throws: PackageInstallationError.invalidFont("fonts/font.otf")) {
            try installer.install(archiveURL)
        }
        #expect(try publishedPackageDirectories(in: library).isEmpty)
    }
}

private func validPackArchive(licenseText: String) throws -> URL {
    try makeTestArchive([
        TestArchiveEntry(path: "habitat.json", data: try minimalManifestData()),
        TestArchiveEntry(path: "preview.png", data: try testPNG()),
        TestArchiveEntry(path: "LICENSE", data: Data(licenseText.utf8)),
    ])
}

private func withTemporaryLibrary(_ operation: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatInstallerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    try operation(root)
}

private func stagingDirectories(in library: URL) throws -> [URL] {
    guard FileManager.default.fileExists(atPath: library.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(
        at: library,
        includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix(".install-") }
}

private func publishedPackageDirectories(in library: URL) throws -> [URL] {
    guard FileManager.default.fileExists(atPath: library.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(
        at: library,
        includingPropertiesForKeys: nil
    ).filter { !$0.lastPathComponent.hasPrefix(".") }
}

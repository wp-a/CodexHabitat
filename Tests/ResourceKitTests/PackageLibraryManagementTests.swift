import Foundation
import Testing
@testable import ResourceKit

@Test
func exportedInstalledPackageCanBeValidatedAndReinstalled() throws {
    let sourceLibrary = temporaryLibrary("Source")
    let destinationLibrary = temporaryLibrary("Destination")
    let exportURL = FileManager.default.temporaryDirectory.appending(
        path: "HabitatExport-\(UUID().uuidString).habitat-pack"
    )
    defer {
        try? FileManager.default.removeItem(at: sourceLibrary)
        try? FileManager.default.removeItem(at: destinationLibrary)
        try? FileManager.default.removeItem(at: exportURL)
    }
    let sourceArchive = try makeTestArchive([
        TestArchiveEntry(path: "habitat.json", data: try minimalManifestData()),
        TestArchiveEntry(path: "preview.png", data: try testPNG()),
        TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
    ])
    defer { try? FileManager.default.removeItem(at: sourceArchive) }
    let installed = try PackageInstaller(
        libraryRoot: sourceLibrary,
        runtimeVersion: "1.0.0"
    ).install(sourceArchive)

    try InstalledPackageLibrary(
        root: sourceLibrary,
        runtimeVersion: "1.0.0"
    ).export(packageID: installed.id, to: exportURL)

    _ = try ArchiveInspector().inspect(exportURL)
    let reinstalled = try PackageInstaller(
        libraryRoot: destinationLibrary,
        runtimeVersion: "1.0.0"
    ).install(exportURL)
    #expect(reinstalled.manifest == installed.manifest)
}

@Test
func uninstallRemovesOnlyAValidatedPackageDirectory() throws {
    let libraryRoot = temporaryLibrary("Uninstall")
    defer { try? FileManager.default.removeItem(at: libraryRoot) }
    let firstArchive = try makeTestArchive([
        TestArchiveEntry(path: "habitat.json", data: try minimalManifestData(id: "studio.example.first")),
        TestArchiveEntry(path: "preview.png", data: try testPNG()),
        TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
    ])
    let secondArchive = try makeTestArchive([
        TestArchiveEntry(path: "habitat.json", data: try minimalManifestData(id: "studio.example.second")),
        TestArchiveEntry(path: "preview.png", data: try testPNG()),
        TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
    ])
    defer {
        try? FileManager.default.removeItem(at: firstArchive)
        try? FileManager.default.removeItem(at: secondArchive)
    }
    let installer = PackageInstaller(libraryRoot: libraryRoot, runtimeVersion: "1.0.0")
    _ = try installer.install(firstArchive)
    _ = try installer.install(secondArchive)
    let library = InstalledPackageLibrary(root: libraryRoot, runtimeVersion: "1.0.0")

    try library.uninstall(packageID: "studio.example.first")

    #expect(library.currentPackages().map(\.id) == ["studio.example.second"])
    #expect(throws: PackageLibraryError.packageNotFound) {
        try library.uninstall(packageID: "../second")
    }
}

private func temporaryLibrary(_ label: String) -> URL {
    FileManager.default.temporaryDirectory.appending(
        path: "HabitatPackage\(label)-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
}

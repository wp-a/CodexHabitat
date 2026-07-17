import Foundation
import Testing
@testable import ResourceKit

@Test
func installedLibrarySelectsTheHighestValidSemanticVersionPerPackage() throws {
    let root = temporaryInstalledLibraryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    try writeInstalledManifest(root: root, directoryID: "studio.example.pack", version: "1.9.0")
    try writeInstalledManifest(root: root, directoryID: "studio.example.pack", version: "1.10.0")

    let packages = InstalledPackageLibrary(
        root: root,
        runtimeVersion: "1.0.0"
    ).currentPackages()

    #expect(packages.count == 1)
    #expect(packages.first?.id == "studio.example.pack")
    #expect(packages.first?.version == "1.10.0")
}

@Test
func installedLibraryIgnoresMismatchedDirectoriesAndMalformedManifests() throws {
    let root = temporaryInstalledLibraryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    try writeInstalledManifest(
        root: root,
        directoryID: "studio.example.wrong-directory",
        manifestID: "studio.example.pack",
        version: "1.0.0"
    )
    let malformed = root.appending(path: "studio.example.bad/1.0.0", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: malformed, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: malformed.appending(path: "habitat.json"))

    let packages = InstalledPackageLibrary(
        root: root,
        runtimeVersion: "1.0.0"
    ).currentPackages()

    #expect(packages.isEmpty)
}

private func temporaryInstalledLibraryRoot() -> URL {
    FileManager.default.temporaryDirectory.appending(
        path: "InstalledPackageLibraryTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
}

private func writeInstalledManifest(
    root: URL,
    directoryID: String,
    manifestID: String? = nil,
    version: String
) throws {
    let directory = root.appending(
        path: "\(directoryID)/\(version)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let object: [String: Any] = [
        "schemaVersion": 1,
        "id": manifestID ?? directoryID,
        "name": "Installed Pack",
        "version": version,
        "author": "Habitat",
        "license": ["spdx": "MIT", "file": "LICENSE"],
        "minimumRuntimeVersion": "1.0.0",
        "modes": ["light"],
        "preview": "preview.png",
        "colors": [
            "surface": "#FFFFFF", "text": "#111111", "accent": "#008080",
            "attention": "#D97706", "error": "#D64545",
        ],
        "assets": [],
        "pets": [],
        "widgets": [],
    ]
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    try data.write(to: directory.appending(path: "habitat.json"))
}

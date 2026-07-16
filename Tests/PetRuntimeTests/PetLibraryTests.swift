import Foundation
import Testing
@testable import PetRuntime

@Test
func codexHomeTakesPrecedenceOverDefaultHome() {
    let customCodexHome = URL(fileURLWithPath: "/tmp/custom-codex-home")
    let home = URL(fileURLWithPath: "/tmp/example-home")

    let custom = PetLibrary.petRoot(
        environment: ["CODEX_HOME": customCodexHome.path],
        homeDirectory: home
    )
    let fallback = PetLibrary.petRoot(environment: [:], homeDirectory: home)

    #expect(custom == customCodexHome.appending(path: "pets", directoryHint: .isDirectory))
    #expect(fallback == home.appending(path: ".codex/pets", directoryHint: .isDirectory))
}

@Test
func discoveryKeepsValidAndInvalidPetsIsolated() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    try copyFixture("valid-pet", to: root.appending(path: "valid-pet"))
    try copyFixture("invalid-pet", to: root.appending(path: "invalid-pet"))

    let entries = try PetLibrary(root: root).discover()

    #expect(entries.count == 2)
    #expect(entries.first(where: { $0.manifest?.id == "test-pet" })?.status == .valid)
    #expect(
        entries.first(where: { $0.manifest?.id == "broken-pet" })?.status
            == .invalid(.spritesheetMissing)
    )
}

@Test
func duplicateIDsAreReportedWithoutDroppingEitherEntry() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    try copyFixture("valid-pet", to: root.appending(path: "first"))
    try copyFixture("valid-pet", to: root.appending(path: "second"))

    let entries = try PetLibrary(root: root).discover()

    #expect(entries.count == 2)
    #expect(entries.filter { $0.status == .valid }.count == 1)
    #expect(entries.filter { $0.status == .duplicateID }.count == 1)
}

@Test
func traversalAndWrongAtlasGeometryAreRejected() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let traversal = root.appending(path: "traversal", directoryHint: .isDirectory)
    let wrongGeometry = root.appending(path: "wrong-geometry", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: traversal, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: wrongGeometry, withIntermediateDirectories: true)
    try manifest(id: "traversal", path: "../outside.png").write(
        to: traversal.appending(path: "pet.json")
    )
    try manifest(id: "wrong-geometry", path: "spritesheet.png", version: 2).write(
        to: wrongGeometry.appending(path: "pet.json")
    )
    try Data(contentsOf: fixtureURL("valid-pet", file: "spritesheet.png")).write(
        to: wrongGeometry.appending(path: "spritesheet.png")
    )

    let traversalEntry = PetValidator().validate(directory: traversal)
    #expect(traversalEntry.status == .invalid(.spritesheetPathEscapesPackage))
    #expect(
        PetValidator().validate(directory: wrongGeometry).status
            == .invalid(.invalidSpritesheetDimensions)
    )
}

@Test
func discoveryDoesNotModifySourcePetFiles() throws {
    let directory = try #require(
        Bundle.module.url(forResource: "valid-pet", withExtension: nil, subdirectory: "Fixtures")
    )
    let manifestURL = directory.appending(path: "pet.json")
    let atlasURL = directory.appending(path: "spritesheet.png")
    let beforeManifest = try attributes(manifestURL)
    let beforeAtlas = try attributes(atlasURL)

    _ = PetValidator().validate(directory: directory)

    #expect(try attributes(manifestURL) == beforeManifest)
    #expect(try attributes(atlasURL) == beforeAtlas)
}

private func temporaryLibrary() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "PetLibraryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func copyFixture(_ name: String, to destination: URL) throws {
    let source = try #require(
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
    )
    try FileManager.default.copyItem(at: source, to: destination)
}

private func fixtureURL(_ fixture: String, file: String) throws -> URL {
    let directory = try #require(
        Bundle.module.url(forResource: fixture, withExtension: nil, subdirectory: "Fixtures")
    )
    return directory.appending(path: file)
}

private func manifest(id: String, path: String, version: Int? = nil) throws -> Data {
    var object: [String: Any] = [
        "id": id,
        "displayName": id,
        "description": "Generated test manifest",
        "spritesheetPath": path,
    ]
    object["spriteVersionNumber"] = version
    return try JSONSerialization.data(withJSONObject: object)
}

private func attributes(_ url: URL) throws -> [FileAttributeKey: AnyHashable] {
    let values = try FileManager.default.attributesOfItem(atPath: url.path)
    return [
        .size: values[.size] as? AnyHashable,
        .modificationDate: values[.modificationDate] as? AnyHashable,
        .posixPermissions: values[.posixPermissions] as? AnyHashable,
    ].compactMapValues { $0 }
}

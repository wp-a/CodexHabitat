import CoreGraphics
import Foundation
import ImageIO
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

@Test
func manifestMustBeARegularNonSymlinkFile() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appending(path: "symlink-manifest", directoryHint: .isDirectory)
    let target = root.appending(path: "target.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try manifest(id: "symlink-manifest", path: "spritesheet.png").write(to: target)
    try FileManager.default.createSymbolicLink(
        at: directory.appending(path: "pet.json"),
        withDestinationURL: target
    )

    let entry = PetValidator().validate(directory: directory)

    #expect(entry.status == .invalid(.manifestUnreadable))
}

@Test
func oversizedManifestIsRejectedBeforeDecoding() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appending(path: "oversized-manifest", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var data = try manifest(id: "oversized-manifest", path: "spritesheet.png")
    data.append(Data(repeating: 0x20, count: 300_000))
    try data.write(to: directory.appending(path: "pet.json"))

    let entry = PetValidator().validate(directory: directory)

    #expect(entry.status == .invalid(.manifestUnreadable))
}

@Test
func oversizedManifestTextFieldsAreRejected() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let cases = [
        ("identifier", String(repeating: "a", count: 129), "name", "description"),
        ("display-name", "display-name", String(repeating: "a", count: 257), "description"),
        ("description", "description", "name", String(repeating: "a", count: 4_097)),
    ]

    for (directoryName, id, displayName, description) in cases {
        let directory = root.appending(path: directoryName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try manifest(
            id: id,
            path: "spritesheet.png",
            displayName: displayName,
            description: description
        ).write(to: directory.appending(path: "pet.json"))
        try validSpritesheetData().write(to: directory.appending(path: "spritesheet.png"))

        #expect(PetValidator().validate(directory: directory).status != .valid)
    }
}

@Test
func controlCharactersInManifestTextAreRejected() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let cases = [
        ("display-control", "Unsafe\nname", "description"),
        ("description-control", "name", "Unsafe\tdescription"),
    ]

    for (id, displayName, description) in cases {
        let directory = root.appending(path: id, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try manifest(
            id: id,
            path: "spritesheet.png",
            displayName: displayName,
            description: description
        ).write(to: directory.appending(path: "pet.json"))
        try validSpritesheetData().write(to: directory.appending(path: "spritesheet.png"))

        #expect(
            PetValidator().validate(directory: directory).status
                == .invalid(.manifestUnreadable)
        )
    }
}

@Test
func unsafeOrOversizedRelativeSpritesheetPathsAreRejected() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let normalized = root.appending(path: "normalized", directoryHint: .isDirectory)
    let oversized = root.appending(path: "oversized", directoryHint: .isDirectory)
    let controlCharacter = root.appending(path: "control-character", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: normalized, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: oversized, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
        at: controlCharacter,
        withIntermediateDirectories: true
    )
    try manifest(id: "normalized", path: "assets/../spritesheet.png").write(
        to: normalized.appending(path: "pet.json")
    )
    try validSpritesheetData().write(to: normalized.appending(path: "spritesheet.png"))
    let longPath = Array(repeating: "abcdefghij", count: 100).joined(separator: "/")
        + "/spritesheet.png"
    try manifest(id: "oversized", path: longPath).write(
        to: oversized.appending(path: "pet.json")
    )
    try manifest(id: "control-character", path: "spritesheet\n.png").write(
        to: controlCharacter.appending(path: "pet.json")
    )

    #expect(
        PetValidator().validate(directory: normalized).status
            == .invalid(.spritesheetPathEscapesPackage)
    )
    #expect(
        PetValidator().validate(directory: oversized).status
            == .invalid(.spritesheetPathEscapesPackage)
    )
    #expect(
        PetValidator().validate(directory: controlCharacter).status
            == .invalid(.spritesheetPathEscapesPackage)
    )
}

@Test
func spritesheetMustBeARegularNonSymlinkFile() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appending(path: "symlink-atlas", directoryHint: .isDirectory)
    let target = root.appending(path: "target.png")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try manifest(id: "symlink-atlas", path: "spritesheet.png").write(
        to: directory.appending(path: "pet.json")
    )
    try validSpritesheetData().write(to: target)
    try FileManager.default.createSymbolicLink(
        at: directory.appending(path: "spritesheet.png"),
        withDestinationURL: target
    )

    let entry = PetValidator().validate(directory: directory)

    #expect(entry.status == .invalid(.spritesheetUnreadable))
}

@Test
func oversizedSpritesheetFileIsRejectedBeforeImageInspection() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appending(path: "oversized-atlas", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try manifest(id: "oversized-atlas", path: "spritesheet.png").write(
        to: directory.appending(path: "pet.json")
    )
    var data = try validSpritesheetData()
    data.append(Data(repeating: 0, count: 17 * 1_024 * 1_024))
    try data.write(to: directory.appending(path: "spritesheet.png"))

    let entry = PetValidator().validate(directory: directory)

    #expect(entry.status == .invalid(.spritesheetUnreadable))
}

@Test
func oversizedSpritesheetCanvasAndPixelCountAreRejected() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let cases = [
        ("wide-atlas", 8_200, 9),
        ("tall-atlas", 8, 8_199),
        ("pixel-heavy-atlas", 8_000, 4_050),
    ]

    for (id, width, height) in cases {
        let directory = root.appending(path: id, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try manifest(id: id, path: "spritesheet.png").write(
            to: directory.appending(path: "pet.json")
        )
        try imageData(width: width, height: height).write(
            to: directory.appending(path: "spritesheet.png")
        )

        #expect(
            PetValidator().validate(directory: directory).status
                == .invalid(.invalidSpritesheetDimensions)
        )
    }
}

@Test
func multiframeSpritesheetIsRejected() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appending(path: "animated-atlas", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try manifest(id: "animated-atlas", path: "spritesheet.png").write(
        to: directory.appending(path: "pet.json")
    )
    try multiframeImageData().write(to: directory.appending(path: "spritesheet.png"))

    let entry = PetValidator().validate(directory: directory)

    #expect(entry.status == .invalid(.spritesheetUnreadable))
}

@Test
func unsupportedImageContainerIsRejected() throws {
    let root = try temporaryLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appending(path: "tiff-atlas", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try manifest(id: "tiff-atlas", path: "spritesheet.tiff").write(
        to: directory.appending(path: "pet.json")
    )
    try imageData(width: 8, height: 9, type: "public.tiff" as CFString).write(
        to: directory.appending(path: "spritesheet.tiff")
    )

    let entry = PetValidator().validate(directory: directory)

    #expect(entry.status == .invalid(.spritesheetUnreadable))
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

private func manifest(
    id: String,
    path: String,
    version: Int? = nil,
    displayName: String? = nil,
    description: String = "Generated test manifest"
) throws -> Data {
    var object: [String: Any] = [
        "id": id,
        "displayName": displayName ?? id,
        "description": description,
        "spritesheetPath": path,
    ]
    object["spriteVersionNumber"] = version
    return try JSONSerialization.data(withJSONObject: object)
}

private func validSpritesheetData() throws -> Data {
    try Data(contentsOf: fixtureURL("valid-pet", file: "spritesheet.png"))
}

private func imageData(
    width: Int,
    height: Int,
    type: CFString = "public.png" as CFString
) throws -> Data {
    let bytesPerRow = (width + 7) / 8
    let providerData = Data(repeating: 0, count: bytesPerRow * height)
    let provider = try #require(CGDataProvider(data: providerData as CFData))
    let image = try #require(
        CGImage(
            width: width,
            height: height,
            bitsPerComponent: 1,
            bitsPerPixel: 1,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    )
    let data = NSMutableData()
    let destination = try #require(
        CGImageDestinationCreateWithData(data, type, 1, nil)
    )
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

private func multiframeImageData() throws -> Data {
    let imageData = try imageData(width: 8, height: 9)
    let source = try #require(CGImageSourceCreateWithData(imageData as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let data = NSMutableData()
    let destination = try #require(
        CGImageDestinationCreateWithData(data, "public.png" as CFString, 2, nil)
    )
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

private func attributes(_ url: URL) throws -> [FileAttributeKey: AnyHashable] {
    let values = try FileManager.default.attributesOfItem(atPath: url.path)
    return [
        .size: values[.size] as? AnyHashable,
        .modificationDate: values[.modificationDate] as? AnyHashable,
        .posixPermissions: values[.posixPermissions] as? AnyHashable,
    ].compactMapValues { $0 }
}

import Foundation
import Testing
@testable import HabitatCore

@Test(arguments: ["MacOS", "Helpers"])
func packagedResourcesResolveFromStandardAppContents(_ executableDirectory: String) throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "PackagedResourceLocatorTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let contents = root.appending(path: "Codex Habitat.app/Contents", directoryHint: .isDirectory)
    let executable = contents.appending(
        path: "\(executableDirectory)/Executable"
    )
    let resource = contents.appending(
        path: "Resources/Resources/Themes/workbench/habitat.json"
    )
    try FileManager.default.createDirectory(
        at: executable.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: resource.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("{}".utf8).write(to: resource)

    let located = PackagedResourceLocator.url(
        forResource: "habitat",
        withExtension: "json",
        subdirectory: "Resources/Themes/workbench",
        executableURL: executable
    )

    #expect(located == resource)
}

@Test(arguments: [
    "../Secrets",
    "/tmp/Secrets",
    "Resources/../../Secrets",
    "Resources\\Secrets",
])
func packagedResourceLocatorRejectsUnsafeSubdirectories(_ subdirectory: String) {
    #expect(PackagedResourceLocator.url(
        forResource: "habitat",
        withExtension: "json",
        subdirectory: subdirectory,
        executableURL: URL(fileURLWithPath: "/Applications/Test.app/Contents/MacOS/Test")
    ) == nil)
}

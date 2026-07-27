import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatThemeBridge

@Test
func bundledHelperReadsTheContainingApplicationVersion() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "ThemeBridgeVersion-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let contents = root.appending(path: "Codex Habitat.app/Contents", directoryHint: .isDirectory)
    let helper = contents.appending(path: "Helpers/CodexHabitatThemeBridge")
    try FileManager.default.createDirectory(
        at: helper.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let plist = try PropertyListSerialization.data(
        fromPropertyList: ["CFBundleShortVersionString": "1.2.3"],
        format: .xml,
        options: 0
    )
    try plist.write(to: contents.appending(path: "Info.plist"))

    #expect(ThemeBridgeVersion.resolve(executableURL: helper) == "1.2.3")
}

@Test
func standaloneHelperUsesTheDevelopmentVersionFallback() {
    let executable = URL(fileURLWithPath: "/tmp/CodexHabitatThemeBridge")

    #expect(ThemeBridgeVersion.resolve(executableURL: executable) == HabitatCore.version)
}

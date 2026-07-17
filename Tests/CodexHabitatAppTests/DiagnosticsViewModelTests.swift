import Foundation
import Testing
@testable import CodexHabitatApp

@MainActor
@Test
func resourceCheckExportAndClearUseStableRedactedStates() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "DiagnosticsViewModelTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let appRoot = root.appending(path: "App", directoryHint: .isDirectory)
    let petRoot = root.appending(path: "Pets", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: petRoot, withIntermediateDirectories: true)
    let model = DiagnosticsViewModel(
        root: appRoot,
        petRoot: petRoot,
        appVersion: "0.1.0-dev",
        localization: HabitatLocalization(localeIdentifier: "en")
    )

    await model.validateResources()

    #expect(model.resourceStatus == "0 pets, 0 packs valid")
    #expect(!model.isBusy)

    let exportURL = root.appending(path: "diagnostics.json")
    await model.export(to: exportURL)

    #expect(model.localDataStatus == "Redacted diagnostics exported")
    #expect(model.localDataSucceeded)
    let exported = try String(contentsOf: exportURL, encoding: .utf8)
    #expect(exported.contains("resourcesValidated"))
    #expect(!exported.contains(root.path))

    let previewCache = appRoot.appending(
        path: "Cache/Previews",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: previewCache, withIntermediateDirectories: true)
    try Data("stale".utf8).write(to: previewCache.appending(path: ".preview"))

    await model.clearLocalData()

    #expect(model.localDataStatus == "Diagnostics and preview cache cleared")
    #expect(try FileManager.default.contentsOfDirectory(
        at: previewCache,
        includingPropertiesForKeys: nil
    ).isEmpty)
    await model.refreshEventCount()
    #expect(model.localDataStatus == "0 diagnostic events")
}

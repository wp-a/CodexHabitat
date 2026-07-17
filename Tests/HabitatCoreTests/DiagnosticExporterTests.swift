import Foundation
import Testing
@testable import HabitatCore

@Test
func diagnosticEventsAcceptOnlyStableFieldsAndSanitizeVersions() throws {
    let event = DiagnosticEvent(
        module: .codexConnector,
        code: .connectionUnavailable,
        appVersion: "/Users/alice/project?token=secret",
        codexVersion: "thread_123 bearer-secret",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(event.appVersion == nil)
    #expect(event.codexVersion == nil)
    #expect(DiagnosticEvent(
        module: .application,
        code: .started,
        appVersion: "sk-secret-token"
    ).appVersion == nil)
    #expect(DiagnosticEvent(
        module: .application,
        code: .started,
        appVersion: "0.1.0-dev+42"
    ).appVersion == "0.1.0-dev+42")
    let data = try JSONEncoder().encode(event)
    let text = String(decoding: data, as: UTF8.self)
    #expect(!text.contains("alice"))
    #expect(!text.contains("thread_123"))
    #expect(!text.contains("secret"))
}

@Test
func storeRotatesAfterSevenDaysAndUsesPrivatePermissions() async throws {
    try await withTemporaryDiagnosticRoot { root in
        let store = DiagnosticStore(root: root)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try await store.record(DiagnosticEvent(
            module: .application,
            code: .started,
            appVersion: "1.0.0",
            timestamp: now.addingTimeInterval(-8 * 24 * 60 * 60)
        ), now: now)
        try await store.record(DiagnosticEvent(
            module: .resourceLibrary,
            code: .resourcesValidated,
            appVersion: "1.0.0",
            timestamp: now.addingTimeInterval(-6 * 24 * 60 * 60)
        ), now: now)

        let events = try await store.events(now: now)

        #expect(events.map(\.code) == [.resourcesValidated])
        #expect(try permissions(of: root) == 0o700)
        #expect(try permissions(of: root.appending(path: "events.json")) == 0o600)
    }
}

@Test
func exportIsDeterministicSortedAndDropsUnknownSensitiveFields() async throws {
    try await withTemporaryDiagnosticRoot { root in
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let raw = Data(#"""
        {
          "schemaVersion": 1,
          "events": [
            {
              "module": "themeBridge",
              "code": "themeRestoreFailed",
              "appVersion": "/Users/alice/private",
              "codexVersion": "token=secret",
              "timestamp": 1800000001,
              "threadID": "thread_123",
              "path": "/Users/alice/project",
              "token": "bearer-secret"
            },
            {
              "module": "application",
              "code": "started",
              "appVersion": "1.0.0",
              "timestamp": 1800000000
            }
          ]
        }
        """#.utf8)
        try raw.write(to: root.appending(path: "events.json"))
        let store = DiagnosticStore(root: root)
        let events = try await store.events(now: Date(timeIntervalSince1970: 1_800_000_002))
        let exporter = DiagnosticExporter()
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_003)

        let first = try exporter.data(events: events, exportedAt: exportedAt)
        let second = try exporter.data(events: events.reversed(), exportedAt: exportedAt)
        let text = String(decoding: first, as: UTF8.self)

        #expect(first == second)
        #expect(!text.contains("alice"))
        #expect(!text.contains("thread_123"))
        #expect(!text.contains("bearer-secret"))
        #expect(!text.contains("token=secret"))
        #expect(text.contains("Restore Official Appearance"))
        #expect(text.contains("CodexHabitatThemeBridge"))
    }
}

@Test
func exporterWritesPrivateFilesAndRefusesSymbolicLinkDestinations() async throws {
    try await withTemporaryDiagnosticRoot { root in
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let destination = root.appending(path: "export.json")
        try DiagnosticExporter().export(
            events: [],
            exportedAt: Date(timeIntervalSince1970: 1_800_000_000),
            to: destination
        )
        #expect(try permissions(of: destination) == 0o600)

        let target = root.appending(path: "target.json")
        try Data("untouched".utf8).write(to: target)
        let link = root.appending(path: "link.json")
        try FileManager.default.createSymbolicLink(
            atPath: link.path,
            withDestinationPath: target.path
        )
        #expect(throws: DiagnosticStorageError.unsafeSymbolicLink) {
            try DiagnosticExporter().export(
                events: [],
                exportedAt: Date(timeIntervalSince1970: 1_800_000_000),
                to: link
            )
        }
        #expect(try String(contentsOf: target, encoding: .utf8) == "untouched")

        let dangling = root.appending(path: "dangling.json")
        try FileManager.default.createSymbolicLink(
            atPath: dangling.path,
            withDestinationPath: root.appending(path: "missing.json").path
        )
        #expect(throws: DiagnosticStorageError.unsafeSymbolicLink) {
            try DiagnosticExporter().export(
                events: [],
                exportedAt: Date(timeIntervalSince1970: 1_800_000_000),
                to: dangling
            )
        }
    }
}

@Test
func storeRefusesDanglingEventFileLinks() async throws {
    try await withTemporaryDiagnosticRoot { root in
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            atPath: root.appending(path: "events.json").path,
            withDestinationPath: root.appending(path: "missing.json").path
        )
        let store = DiagnosticStore(root: root)

        await #expect(throws: DiagnosticStorageError.unsafeSymbolicLink) {
            try await store.record(DiagnosticEvent(
                module: .application,
                code: .started,
                appVersion: "1.0.0"
            ))
        }
    }
}

@Test
func maintenanceClearsOnlyPreviewCacheAndDiagnosticEvents() async throws {
    try await withTemporaryDiagnosticRoot { root in
        let appRoot = root.appending(path: "App", directoryHint: .isDirectory)
        let directories = AppDirectories(root: appRoot)
        try directories.prepare()
        try Data("preview".utf8).write(
            to: directories.previewCache.appending(path: "preview.png")
        )
        try Data("hidden".utf8).write(
            to: directories.previewCache.appending(path: ".stale-preview")
        )
        try Data("keep".utf8).write(to: directories.settings)
        let store = DiagnosticStore(root: directories.diagnostics)
        try await store.record(DiagnosticEvent(
            module: .application,
            code: .started,
            appVersion: "1.0.0",
            timestamp: Date(timeIntervalSince1970: 1_800_000_000)
        ), now: Date(timeIntervalSince1970: 1_800_000_000))

        let removed = try DiagnosticMaintenance(root: appRoot).clearPreviewCache()
        try await store.clear()

        #expect(removed == 2)
        #expect(try FileManager.default.contentsOfDirectory(
            at: directories.previewCache,
            includingPropertiesForKeys: nil
        ).isEmpty)
        #expect(FileManager.default.fileExists(atPath: directories.settings.path))
        #expect(try await store.events(now: Date(timeIntervalSince1970: 1_800_000_001)).isEmpty)
        #expect(DiagnosticRecovery.officialAppearanceTitle == "Restore Official Appearance")
        #expect(DiagnosticRecovery.themeBridgeArguments == ["restore"])
    }
}

private func withTemporaryDiagnosticRoot(
    _ operation: (URL) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "CodexHabitatDiagnosticsTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    try await operation(root)
}

private func permissions(of url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
    return permissions.intValue & 0o777
}

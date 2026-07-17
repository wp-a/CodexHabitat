import Foundation
import Testing
@testable import CodexConnector

@Test
func executableLocatorPrefersExplicitThenApplicationThenPath() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatCodexLocator-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let explicit = try makeExecutable(root.appending(path: "explicit-codex"))
    let application = try makeExecutable(root.appending(path: "app-codex"))
    let pathDirectory = root.appending(path: "bin", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: pathDirectory, withIntermediateDirectories: true)
    let pathCodex = try makeExecutable(pathDirectory.appending(path: "codex"))

    #expect(CodexExecutableLocator.locate(
        environment: [
            "CODEX_EXECUTABLE": explicit.path,
            "PATH": pathDirectory.path,
        ],
        applicationCandidates: [application],
        standaloneCandidates: []
    ) == explicit)
    #expect(CodexExecutableLocator.locate(
        environment: ["PATH": pathDirectory.path],
        applicationCandidates: [application],
        standaloneCandidates: []
    ) == application)
    #expect(CodexExecutableLocator.locate(
        environment: ["PATH": pathDirectory.path],
        applicationCandidates: [],
        standaloneCandidates: []
    ) == pathCodex)
}

@Test
func executableLocatorRejectsNonExecutableCandidates() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatCodexLocatorInvalid-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let candidate = root.appending(path: "codex")
    try Data().write(to: candidate)

    #expect(CodexExecutableLocator.locate(
        environment: ["CODEX_EXECUTABLE": candidate.path],
        applicationCandidates: [],
        standaloneCandidates: []
    ) == nil)
}

private func makeExecutable(_ url: URL) throws -> URL {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("#!/bin/sh\n".utf8).write(to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}

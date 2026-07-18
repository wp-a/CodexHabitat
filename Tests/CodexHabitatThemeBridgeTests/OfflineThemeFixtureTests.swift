import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatThemeBridge

@Test
func offlineFixtureCommandAcceptsOnlyProfileVersionAndLocalOutput() throws {
    let outputURL = FileManager.default.temporaryDirectory
        .appending(path: "offline-fixture-\(UUID().uuidString).json")
    let options = try OfflineThemeFixtureCommand.parse(arguments: [
        "offline-fixture",
        "--profile-version", "26.715.31925",
        "--output", outputURL.path,
    ])

    #expect(options.profileVersion == "26.715.31925")
    #expect(options.outputURL == outputURL.standardizedFileURL)

    for arguments in [
        ["offline-fixture", "--profile-version", "26.715.31925"],
        ["offline-fixture", "--profile-version", "26.715.31925", "--output", outputURL.path, "--app", "/Applications/Codex.app"],
        ["offline-fixture", "--profile-version", "26.715.31925", "--output", outputURL.path, "--authorized"],
        ["offline-fixture", "--profile-version", "26.715.31925", "--output", outputURL.path, "start"],
        ["offline-fixture", "--profile-version", "26.715.31925", "--output", outputURL.path, "apply"],
        ["offline-fixture", "--profile-version", "26.715.31925", "--output", outputURL.path, "watch"],
        ["offline-fixture", "--profile-version", "latest", "--output", outputURL.path],
        ["offline-fixture", "--profile-version", "26.715.31925", "--output", "relative.json"],
    ] {
        #expect(throws: OfflineThemeFixtureError.invalidArguments) {
            try OfflineThemeFixtureCommand.parse(arguments: arguments)
        }
    }
}

@Test
func offlineFixturePayloadUsesTheRealResolverCompilerInstallerAndAllBuiltIns() throws {
    let profileStore = try CompatibilityProfileStore.bundled()
    let compiler = try ThemeCompiler.bundled()
    let payload = try OfflineThemeFixtureExporter(
        profileStore: profileStore,
        compiler: compiler,
        resolver: BridgeThemeResolver()
    ).makePayload(profileVersion: "26.715.31925")

    #expect(payload.schemaVersion == 1)
    #expect(payload.profileVersion == "26.715.31925")
    #expect(payload.profile.id == "codex-26.715.31925")
    #expect(payload.profile.selectors.appShell == "#root")
    #expect(payload.routes == ["home", "task"])
    #expect(payload.themes.count == 24)
    #expect(Set(payload.themes.map(\.id)) == Set(BuiltInThemeCatalog.all.map(\.id)))
    #expect(Set(payload.themes.map(\.sourceFingerprint)).count == 24)
    #expect(Set(payload.themes.map(\.cssFingerprint)).count == 24)
    #expect(Set(payload.themes.map(\.artFingerprint)).count == 24)
    #expect(isSHA256(payload.profileFingerprint))
    #expect(isSHA256(payload.templateFingerprint))
    #expect(isSHA256(payload.exporterContractFingerprint))

    for theme in payload.themes {
        #expect(theme.backgroundDataURL.hasPrefix("data:image/jpeg;base64,"))
        #expect(theme.installerExpression.contains("codex-habitat-theme-style"))
        #expect(theme.installerExpression.contains("const homeMarker ="))
        #expect(theme.installerExpression.contains("home-icon"))
        #expect(theme.installerExpression.contains("MutationObserver"))
        #expect(theme.installerExpression.contains("data-codex-habitat-surface"))
        #expect(isSHA256(theme.sourceFingerprint))
        #expect(isSHA256(theme.cssFingerprint))
        #expect(isSHA256(theme.artFingerprint))
    }
}

@Test
func offlineFixtureWriterUsesPrivatePermissionsAndDecodablePayload() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatOfflineFixture-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let outputURL = root.appending(path: "payload.json")

    let command = try OfflineThemeFixtureCommand.bundled()
    try command.run(options: OfflineThemeFixtureOptions(
        profileVersion: "26.715.31925",
        outputURL: outputURL
    ))

    let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    let payload = try JSONDecoder().decode(
        OfflineThemeFixturePayload.self,
        from: Data(contentsOf: outputURL)
    )
    #expect(payload.themes.count == 24)
}

@Test
func offlineFixtureReplacementIsPrivateBeforePostWriteVerification() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatOfflineFixture-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let outputURL = root.appending(path: "payload.json")
    try Data("old payload".utf8).write(to: outputURL)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o644],
        ofItemAtPath: outputURL.path
    )
    let fileManager = PermissionAuditingFileManager(observedPath: outputURL.path)

    let command = try OfflineThemeFixtureCommand.bundled(fileManager: fileManager)
    try command.run(options: OfflineThemeFixtureOptions(
        profileVersion: "26.715.31925",
        outputURL: outputURL
    ))

    #expect(fileManager.permissionsBeforePostWriteVerification == 0o600)
}

@Test
func offlineFixtureSourceCannotConstructOrAddressLiveCodexSystems() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatThemeBridge/Fixtures/OfflineThemeFixturePayload.swift"
        ),
        encoding: .utf8
    )
    for forbidden in [
        "ThemeSession(", "ThemeBridgeCoordinator(", "LoopbackListenerVerifier(",
        "LiveCDPClientProvider(", "LiveCodexApplicationRestarter(",
        "LiveThemeProcessSignaler(", "resolveBundle(", "--app", "--authorized",
        "127.0.0.1", "localhost",
    ] {
        #expect(!source.contains(forbidden))
    }
    #expect(source.contains("BridgeThemeResolver"))
    #expect(source.contains("ThemeCompiler"))

    let package = try String(
        contentsOf: repositoryRoot.appending(path: "Package.swift"),
        encoding: .utf8
    )
    #expect(package.contains("HABITAT_OFFLINE_FIXTURE"))
    #expect(package.contains(".when(configuration: .debug)"))

    let verifier = try String(
        contentsOf: repositoryRoot.appending(path: "scripts/verify-release.sh"),
        encoding: .utf8
    )
    #expect(verifier.contains("offline-fixture"))
    #expect(verifier.contains("offline-theme-fixture-payload-v1"))
}

private func isSHA256(_ value: String) -> Bool {
    value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
}

private final class PermissionAuditingFileManager: FileManager, @unchecked Sendable {
    let observedPath: String
    var permissionsBeforePostWriteVerification: Int?

    init(observedPath: String) {
        self.observedPath = observedPath
        super.init()
    }

    override func setAttributes(
        _ attributes: [FileAttributeKey: Any],
        ofItemAtPath path: String
    ) throws {
        if path == observedPath {
            let existing = try super.attributesOfItem(atPath: path)
            permissionsBeforePostWriteVerification =
                (existing[.posixPermissions] as? NSNumber)?.intValue
        }
        try super.setAttributes(attributes, ofItemAtPath: path)
    }
}

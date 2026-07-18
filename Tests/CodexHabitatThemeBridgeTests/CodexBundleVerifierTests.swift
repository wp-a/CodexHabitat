import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func officialIdentitySignatureArchitectureAndExecutablePathAreRequired() throws {
    let root = URL(fileURLWithPath: "/Applications", isDirectory: true)
    let bundleURL = root.appending(path: "ChatGPT.app", directoryHint: .isDirectory)
    let executableURL = bundleURL.appending(path: "Contents/MacOS/ChatGPT")
    let valid = CodexBundleMetadata(
        bundleIdentifier: "com.openai.codex",
        teamIdentifier: "2DC432GLL2",
        version: "26.707.91948",
        executableURL: executableURL,
        architectures: [.current],
        strictSignatureValid: true
    )
    let verifier = CodexBundleVerifier(
        inspector: StubBundleInspector(metadata: valid),
        allowedBundleRoots: [root]
    )

    let verified = try verifier.verify(bundleURL)

    #expect(verified.bundleIdentifier == "com.openai.codex")
    #expect(verified.teamIdentifier == "2DC432GLL2")
    #expect(verified.version == "26.707.91948")
    #expect(verified.executableURL == executableURL)
}

@Test
func verifiedCurrentBundleVersionResolvesOnlyItsExactSurfaceProfile() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )

    #expect(profile.id == "codex-26.715.31925")
    #expect(profile.minimumVersion == "26.715.31925")
    #expect(profile.maximumVersionExclusive == "26.715.31926")
    #expect(profile.selectors.appShell == "#root")
}

@Test(arguments: [
    (
        CodexBundleMetadata(
            bundleIdentifier: "example.fake",
            teamIdentifier: "2DC432GLL2",
            version: "1.0.0",
            executableURL: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"),
            architectures: [.current],
            strictSignatureValid: true
        ),
        CodexBundleVerificationError.unexpectedBundleIdentifier("example.fake")
    ),
    (
        CodexBundleMetadata(
            bundleIdentifier: "com.openai.codex",
            teamIdentifier: "FAKETEAM01",
            version: "1.0.0",
            executableURL: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"),
            architectures: [.current],
            strictSignatureValid: true
        ),
        CodexBundleVerificationError.unexpectedTeamIdentifier("FAKETEAM01")
    ),
    (
        CodexBundleMetadata(
            bundleIdentifier: "com.openai.codex",
            teamIdentifier: "2DC432GLL2",
            version: "1.0.0",
            executableURL: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"),
            architectures: [.current],
            strictSignatureValid: false
        ),
        CodexBundleVerificationError.invalidCodeSignature
    ),
])
func invalidOfficialIdentityIsRejected(
    metadata: CodexBundleMetadata,
    expected: CodexBundleVerificationError
) {
    let verifier = CodexBundleVerifier(
        inspector: StubBundleInspector(metadata: metadata),
        allowedBundleRoots: [URL(fileURLWithPath: "/Applications", isDirectory: true)]
    )

    #expect(throws: expected) {
        try verifier.verify(URL(fileURLWithPath: "/Applications/ChatGPT.app"))
    }
}

@Test
func wrongArchitectureExecutableEscapeAndUnapprovedRootAreRejected() {
    let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
    let bundleURL = applications.appending(path: "ChatGPT.app", directoryHint: .isDirectory)
    let wrongArchitecture: CodexArchitecture = CodexArchitecture.current == .arm64
        ? .x86_64
        : .arm64
    let architectureMetadata = CodexBundleMetadata(
        bundleIdentifier: "com.openai.codex",
        teamIdentifier: "2DC432GLL2",
        version: "1.0.0",
        executableURL: bundleURL.appending(path: "Contents/MacOS/ChatGPT"),
        architectures: [wrongArchitecture],
        strictSignatureValid: true
    )
    #expect(throws: CodexBundleVerificationError.unsupportedArchitecture(.current)) {
        try CodexBundleVerifier(
            inspector: StubBundleInspector(metadata: architectureMetadata),
            allowedBundleRoots: [applications]
        ).verify(bundleURL)
    }

    let escaped = CodexBundleMetadata(
        bundleIdentifier: "com.openai.codex",
        teamIdentifier: "2DC432GLL2",
        version: "1.0.0",
        executableURL: URL(fileURLWithPath: "/tmp/ChatGPT"),
        architectures: [.current],
        strictSignatureValid: true
    )
    #expect(throws: CodexBundleVerificationError.unsafeExecutablePath) {
        try CodexBundleVerifier(
            inspector: StubBundleInspector(metadata: escaped),
            allowedBundleRoots: [applications]
        ).verify(bundleURL)
    }

    #expect(throws: CodexBundleVerificationError.unapprovedBundleLocation) {
        try CodexBundleVerifier(
            inspector: StubBundleInspector(metadata: architectureMetadata),
            allowedBundleRoots: [applications]
        ).verify(URL(fileURLWithPath: "/tmp/ChatGPT.app"))
    }
}

private struct StubBundleInspector: CodexBundleInspecting {
    let metadata: CodexBundleMetadata

    func inspect(_ bundleURL: URL) throws -> CodexBundleMetadata {
        metadata
    }
}

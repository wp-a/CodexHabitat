import Foundation
import MachO
import Security

enum CodexArchitecture: String, Codable, Equatable, Hashable, Sendable {
    case arm64
    case x86_64

    static var current: CodexArchitecture {
        #if arch(arm64)
        .arm64
        #elseif arch(x86_64)
        .x86_64
        #else
        #error("Codex Habitat Theme Bridge supports arm64 and x86_64 macOS only")
        #endif
    }
}

struct CodexBundleMetadata: Equatable, Sendable {
    let bundleIdentifier: String
    let teamIdentifier: String
    let version: String
    let executableURL: URL
    let architectures: Set<CodexArchitecture>
    let strictSignatureValid: Bool
}

struct VerifiedCodexBundle: Equatable, Sendable {
    let bundleURL: URL
    let executableURL: URL
    let bundleIdentifier: String
    let teamIdentifier: String
    let version: String
    let architectures: Set<CodexArchitecture>
}

enum CodexBundleVerificationError: Error, Equatable, Sendable {
    case unapprovedBundleLocation
    case inspectionFailed
    case unexpectedBundleIdentifier(String)
    case unexpectedTeamIdentifier(String)
    case invalidCodeSignature
    case unsupportedArchitecture(CodexArchitecture)
    case unsafeExecutablePath
    case missingVersion
}

protocol CodexBundleInspecting {
    func inspect(_ bundleURL: URL) throws -> CodexBundleMetadata
}

protocol CodexBundleVerifying {
    func verify(_ bundleURL: URL) throws -> VerifiedCodexBundle
}

struct CodexBundleVerifier: CodexBundleVerifying {
    static let officialBundleIdentifier = "com.openai.codex"
    static let officialTeamIdentifier = "2DC432GLL2"

    private let inspector: any CodexBundleInspecting
    private let allowedBundleRoots: [URL]

    init(
        inspector: any CodexBundleInspecting = LiveCodexBundleInspector(),
        allowedBundleRoots: [URL] = CodexBundleVerifier.defaultBundleRoots()
    ) {
        self.inspector = inspector
        self.allowedBundleRoots = allowedBundleRoots
    }

    func verify(_ bundleURL: URL) throws -> VerifiedCodexBundle {
        let normalizedBundle = bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        guard normalizedBundle.pathExtension == "app",
              allowedBundleRoots.contains(where: { root in
                  normalizedBundle.deletingLastPathComponent()
                      == root.standardizedFileURL.resolvingSymlinksInPath()
              })
        else {
            throw CodexBundleVerificationError.unapprovedBundleLocation
        }

        let metadata = try inspector.inspect(normalizedBundle)
        guard metadata.bundleIdentifier == Self.officialBundleIdentifier else {
            throw CodexBundleVerificationError.unexpectedBundleIdentifier(
                metadata.bundleIdentifier
            )
        }
        guard metadata.teamIdentifier == Self.officialTeamIdentifier else {
            throw CodexBundleVerificationError.unexpectedTeamIdentifier(
                metadata.teamIdentifier
            )
        }
        guard metadata.strictSignatureValid else {
            throw CodexBundleVerificationError.invalidCodeSignature
        }
        guard metadata.architectures.contains(.current) else {
            throw CodexBundleVerificationError.unsupportedArchitecture(.current)
        }
        guard !metadata.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodexBundleVerificationError.missingVersion
        }

        let expectedExecutableDirectory = normalizedBundle
            .appending(path: "Contents/MacOS", directoryHint: .isDirectory)
        let normalizedExecutable = metadata.executableURL.standardizedFileURL
            .resolvingSymlinksInPath()
        guard normalizedExecutable.deletingLastPathComponent() == expectedExecutableDirectory else {
            throw CodexBundleVerificationError.unsafeExecutablePath
        }
        if FileManager.default.fileExists(atPath: normalizedExecutable.path) {
            let values = try? normalizedExecutable.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isExecutableKey]
            )
            guard values?.isRegularFile == true,
                  values?.isSymbolicLink != true,
                  values?.isExecutable == true
            else {
                throw CodexBundleVerificationError.unsafeExecutablePath
            }
        }

        return VerifiedCodexBundle(
            bundleURL: normalizedBundle,
            executableURL: normalizedExecutable,
            bundleIdentifier: metadata.bundleIdentifier,
            teamIdentifier: metadata.teamIdentifier,
            version: metadata.version,
            architectures: metadata.architectures
        )
    }

    static func defaultBundleRoots(
        fileManager: FileManager = .default
    ) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appending(
                path: "Applications",
                directoryHint: .isDirectory
            ),
        ]
    }
}

struct LiveCodexBundleInspector: CodexBundleInspecting {
    func inspect(_ bundleURL: URL) throws -> CodexBundleMetadata {
        guard let bundle = Bundle(url: bundleURL),
              let bundleIdentifier = bundle.bundleIdentifier,
              let executableURL = bundle.executableURL
        else {
            throw CodexBundleVerificationError.inspectionFailed
        }
        let version = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? ""
        let architectures: Set<CodexArchitecture> = Set(
            (bundle.executableArchitectures ?? []).compactMap { value in
                switch value.int32Value {
                case CPU_TYPE_ARM64: .arm64
                case CPU_TYPE_X86_64: .x86_64
                default: nil
                }
            }
        )

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode
        else {
            throw CodexBundleVerificationError.inspectionFailed
        }
        var signingInformation: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: UInt32(kSecCSSigningInformation)),
            &signingInformation
        ) == errSecSuccess,
        let information = signingInformation as? [String: Any],
        let teamIdentifier = information[kSecCodeInfoTeamIdentifier as String] as? String
        else {
            throw CodexBundleVerificationError.inspectionFailed
        }
        let flags = SecCSFlags(
            rawValue: UInt32(
                kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode
            )
        )
        var validationError: Unmanaged<CFError>?
        let signatureValid = SecStaticCodeCheckValidityWithErrors(
            staticCode,
            flags,
            nil,
            &validationError
        ) == errSecSuccess
        if let validationError {
            validationError.release()
        }

        return CodexBundleMetadata(
            bundleIdentifier: bundleIdentifier,
            teamIdentifier: teamIdentifier,
            version: version,
            executableURL: executableURL,
            architectures: architectures,
            strictSignatureValid: signatureValid
        )
    }
}

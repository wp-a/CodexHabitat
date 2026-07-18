#if HABITAT_OFFLINE_FIXTURE
import CryptoKit
import Foundation
import HabitatCore

enum OfflineThemeFixtureError: Error, Equatable {
    case invalidArguments
    case unsupportedProfile
    case missingArt(String)
    case unsafeOutput
}

struct OfflineThemeFixtureOptions: Equatable, Sendable {
    let profileVersion: String
    let outputURL: URL
}

struct OfflineThemeFixtureTheme: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let styleFamily: String
    let backgroundDataURL: String
    let installerExpression: String
    let sourceFingerprint: String
    let cssFingerprint: String
    let artFingerprint: String
}

struct OfflineThemeFixturePayload: Codable, Equatable, Sendable {
    static let schemaMarker = "offline-theme-fixture-payload-v1"

    let schemaVersion: Int
    let profileVersion: String
    let profile: CompatibilityProfile
    let routes: [String]
    let profileFingerprint: String
    let templateFingerprint: String
    let exporterContractFingerprint: String
    let themes: [OfflineThemeFixtureTheme]
}

struct OfflineThemeFixtureExporter {
    let profileStore: CompatibilityProfileStore
    let compiler: ThemeCompiler
    let resolver: BridgeThemeResolver

    func makePayload(profileVersion: String) throws -> OfflineThemeFixturePayload {
        guard let profile = profileStore.profile(forVersion: profileVersion) else {
            throw OfflineThemeFixtureError.unsupportedProfile
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let annotations = HostSurfaceAnnotationPlan(profile: profile)
        let themes = try BuiltInThemeCatalog.all.map { definition in
            let theme = try resolver.resolve(id: definition.id)
            guard let backgroundDataURL = theme.artDataURL,
                  let artData = Self.artData(from: backgroundDataURL)
            else {
                throw OfflineThemeFixtureError.missingArt(definition.id)
            }
            let css = try compiler.compile(theme: theme, profile: profile)
            let cssFingerprint = Self.sha256(Data(css.utf8))
            let artFingerprint = Self.sha256(artData)
            let sourceFingerprint = Self.sha256(Data([
                definition.id,
                definition.name,
                definition.styleFamily.rawValue,
                cssFingerprint,
                artFingerprint,
            ].joined(separator: "\0").utf8))
            return OfflineThemeFixtureTheme(
                id: definition.id,
                name: definition.name,
                styleFamily: definition.styleFamily.rawValue,
                backgroundDataURL: backgroundDataURL,
                installerExpression: CDPClient.offlineFixtureInstallerExpression(
                    css: css,
                    homeMarker: profile.selectors.homeMarker,
                    annotations: annotations
                ),
                sourceFingerprint: sourceFingerprint,
                cssFingerprint: cssFingerprint,
                artFingerprint: artFingerprint
            )
        }
        return OfflineThemeFixturePayload(
            schemaVersion: 1,
            profileVersion: profileVersion,
            profile: profile,
            routes: ["home", "task"],
            profileFingerprint: Self.sha256(try encoder.encode(profile)),
            templateFingerprint: compiler.templateFingerprint,
            exporterContractFingerprint: Self.sha256(
                Data(OfflineThemeFixturePayload.schemaMarker.utf8)
            ),
            themes: themes
        )
    }

    private static func artData(from dataURL: String) -> Data? {
        guard let comma = dataURL.firstIndex(of: ","),
              dataURL[..<comma].hasSuffix(";base64")
        else {
            return nil
        }
        return Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...]))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct OfflineThemeFixtureCommand {
    let exporter: OfflineThemeFixtureExporter
    let fileManager: FileManager

    static func bundled(fileManager: FileManager = .default) throws -> Self {
        OfflineThemeFixtureCommand(
            exporter: OfflineThemeFixtureExporter(
                profileStore: try CompatibilityProfileStore.bundled(),
                compiler: try ThemeCompiler.bundled(),
                resolver: BridgeThemeResolver()
            ),
            fileManager: fileManager
        )
    }

    static func parse(arguments: [String]) throws -> OfflineThemeFixtureOptions {
        guard arguments.count == 5,
              arguments[0] == "offline-fixture",
              arguments[1] == "--profile-version",
              arguments[2].range(
                  of: "^[0-9]+\\.[0-9]+(\\.[0-9]+){0,2}$",
                  options: .regularExpression
              ) != nil,
              arguments[3] == "--output",
              arguments[4].hasPrefix("/")
        else {
            throw OfflineThemeFixtureError.invalidArguments
        }
        let outputURL = URL(fileURLWithPath: arguments[4]).standardizedFileURL
        guard outputURL.pathExtension.lowercased() == "json" else {
            throw OfflineThemeFixtureError.invalidArguments
        }
        return OfflineThemeFixtureOptions(
            profileVersion: arguments[2],
            outputURL: outputURL
        )
    }

    func run(options: OfflineThemeFixtureOptions) throws {
        try validateOutput(options.outputURL)
        let payload = try exporter.makePayload(profileVersion: options.profileVersion)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(payload)
        try writePrivate(data, to: options.outputURL)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: options.outputURL.path
        )
    }

    private func writePrivate(_ data: Data, to outputURL: URL) throws {
        let temporaryURL = outputURL.deletingLastPathComponent().appending(
            path: ".\(outputURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        guard fileManager.createFile(
            atPath: temporaryURL.path,
            contents: data,
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw OfflineThemeFixtureError.unsafeOutput
        }
        defer { try? fileManager.removeItem(at: temporaryURL) }
        if fileManager.fileExists(atPath: outputURL.path) {
            _ = try fileManager.replaceItemAt(
                outputURL,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: .usingNewMetadataOnly
            )
        } else {
            try fileManager.moveItem(at: temporaryURL, to: outputURL)
        }
    }

    private func validateOutput(_ outputURL: URL) throws {
        let parentURL = outputURL.deletingLastPathComponent()
        guard let parentValues = try? parentURL.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey,
        ]),
        parentValues.isDirectory == true,
        parentValues.isSymbolicLink != true
        else {
            throw OfflineThemeFixtureError.unsafeOutput
        }
        if fileManager.fileExists(atPath: outputURL.path) {
            guard let outputValues = try? outputURL.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey,
            ]),
            outputValues.isRegularFile == true,
            outputValues.isSymbolicLink != true
            else {
                throw OfflineThemeFixtureError.unsafeOutput
            }
        }
    }
}
#endif

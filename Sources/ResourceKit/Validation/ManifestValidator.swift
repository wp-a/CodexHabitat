import Foundation
import HabitatCore

public enum ManifestValidationError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case invalidIdentity(String)
    case invalidTextField(String)
    case invalidSemanticVersion(String)
    case incompatibleRuntime(required: String, current: String)
    case invalidLicense
    case invalidModes
    case unsafePath(String)
    case unsupportedAssetType(String)
    case invalidSHA256(String)
    case invalidColorToken(String)
    case duplicateIdentifier(String)
    case duplicatePath(String)
    case numericOutOfRange(String)
    case widgetConfigurationMismatch(WidgetIdentifier)
}

public struct ManifestValidator: Sendable {
    public let runtimeVersion: String

    public init(runtimeVersion: String) {
        self.runtimeVersion = runtimeVersion
    }

    public func validate(_ manifest: HabitatManifest) throws {
        guard manifest.schemaVersion == 1 else {
            throw ManifestValidationError.unsupportedSchemaVersion(manifest.schemaVersion)
        }
        try validateIdentifier(manifest.id)
        try validateText(manifest.name, field: "name", maximum: 100)
        try validateText(manifest.author, field: "author", maximum: 100)

        guard let packageVersion = SemanticVersion(manifest.version) else {
            throw ManifestValidationError.invalidSemanticVersion("version")
        }
        guard let minimumRuntime = SemanticVersion(manifest.minimumRuntimeVersion) else {
            throw ManifestValidationError.invalidSemanticVersion("minimumRuntimeVersion")
        }
        guard let currentRuntime = SemanticVersion(runtimeVersion) else {
            throw ManifestValidationError.invalidSemanticVersion("runtimeVersion")
        }
        _ = packageVersion
        guard minimumRuntime <= currentRuntime else {
            throw ManifestValidationError.incompatibleRuntime(
                required: manifest.minimumRuntimeVersion,
                current: runtimeVersion
            )
        }

        try validateLicense(manifest.license)
        guard !manifest.modes.isEmpty,
              manifest.modes.count == Set(manifest.modes).count
        else {
            throw ManifestValidationError.invalidModes
        }
        try validatePath(manifest.preview, extensions: ["png", "jpg", "jpeg", "webp"])
        for (name, value) in manifest.colors.all {
            guard matches(value, pattern: "^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$") else {
                throw ManifestValidationError.invalidColorToken(name)
            }
        }

        guard manifest.assets.count <= 64 else {
            throw ManifestValidationError.numericOutOfRange("assets")
        }
        var resourceIDs: Set<String> = []
        var resourcePaths: Set<String> = []
        for resource in manifest.assets {
            switch resource {
            case let .image(image):
                try validateResourceIdentity(
                    id: image.id,
                    path: image.path,
                    sha256: image.sha256,
                    extensions: ["png", "jpg", "jpeg", "webp"],
                    ids: &resourceIDs,
                    paths: &resourcePaths
                )
            case let .font(font):
                try validateResourceIdentity(
                    id: font.id,
                    path: font.path,
                    sha256: font.sha256,
                    extensions: ["otf", "ttf", "woff2"],
                    ids: &resourceIDs,
                    paths: &resourcePaths
                )
            }
        }

        guard manifest.pets.count <= 16 else {
            throw ManifestValidationError.numericOutOfRange("pets")
        }
        var petIDs: Set<String> = []
        for pet in manifest.pets {
            try validateIdentifier(pet.id)
            guard petIDs.insert(pet.id).inserted else {
                throw ManifestValidationError.duplicateIdentifier(pet.id)
            }
            try validatePath(pet.path)
            guard pet.scale.isFinite, (0.5...2).contains(pet.scale) else {
                throw ManifestValidationError.numericOutOfRange("pet.scale")
            }
        }

        guard manifest.widgets.count <= WidgetIdentifier.allCases.count else {
            throw ManifestValidationError.numericOutOfRange("widgets")
        }
        var widgetIDs: Set<WidgetIdentifier> = []
        for widget in manifest.widgets {
            guard widgetIDs.insert(widget.id).inserted else {
                throw ManifestValidationError.duplicateIdentifier(widget.id.rawValue)
            }
            guard widget.position.x.isFinite,
                  widget.position.y.isFinite,
                  (0...1).contains(widget.position.x),
                  (0...1).contains(widget.position.y)
            else {
                throw ManifestValidationError.numericOutOfRange("widget.position")
            }
            try validateWidget(widget)
        }
    }

    private func validateLicense(_ license: HabitatLicense) throws {
        guard matches(license.spdx, pattern: "^[A-Za-z0-9][A-Za-z0-9.+-]{0,63}$") else {
            throw ManifestValidationError.invalidLicense
        }
        do {
            try validatePath(license.file)
        } catch {
            throw ManifestValidationError.invalidLicense
        }
    }

    private func validateWidget(_ widget: HabitatWidget) throws {
        switch (widget.id, widget.configuration) {
        case (.status, .status), (.usage, .usage), (.clock, .clock):
            return
        case let (.pomodoro, .pomodoro(configuration)):
            guard (60...86_400).contains(configuration.focusSeconds),
                  (60...86_400).contains(configuration.restSeconds)
            else {
                throw ManifestValidationError.numericOutOfRange("pomodoro")
            }
        case let (.countdown, .countdown(configuration)):
            guard (1...86_400).contains(configuration.durationSeconds) else {
                throw ManifestValidationError.numericOutOfRange("countdown")
            }
        default:
            throw ManifestValidationError.widgetConfigurationMismatch(widget.id)
        }
    }

    private func validateResourceIdentity(
        id: String,
        path: String,
        sha256: String,
        extensions: Set<String>,
        ids: inout Set<String>,
        paths: inout Set<String>
    ) throws {
        try validateIdentifier(id)
        guard ids.insert(id).inserted else {
            throw ManifestValidationError.duplicateIdentifier(id)
        }
        try validatePath(path, extensions: extensions)
        guard paths.insert(path.lowercased()).inserted else {
            throw ManifestValidationError.duplicatePath(path)
        }
        guard matches(sha256, pattern: "^[0-9A-Fa-f]{64}$") else {
            throw ManifestValidationError.invalidSHA256(id)
        }
    }

    private func validateIdentifier(_ value: String) throws {
        guard value.count <= 128,
              matches(value, pattern: "^[a-z0-9]+([.-][a-z0-9]+)*$")
        else {
            throw ManifestValidationError.invalidIdentity(value)
        }
    }

    private func validateText(_ value: String, field: String, maximum: Int) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maximum, !value.contains("\0") else {
            throw ManifestValidationError.invalidTextField(field)
        }
    }

    private func validatePath(_ path: String, extensions: Set<String>? = nil) throws {
        guard !path.isEmpty,
              path.count <= 512,
              !path.hasPrefix("/"),
              !path.hasPrefix("~"),
              !path.contains("\\"),
              !path.contains(":"),
              !path.contains("\0")
        else {
            throw ManifestValidationError.unsafePath(path)
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw ManifestValidationError.unsafePath(path)
        }
        if let extensions {
            let pathExtension = URL(fileURLWithPath: path).pathExtension
            guard pathExtension == pathExtension.lowercased(),
                  extensions.contains(pathExtension)
            else {
                throw ManifestValidationError.unsupportedAssetType(path)
            }
        }
    }

    private func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

struct SemanticVersion: Comparable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: [String]?

    init?(_ value: String) {
        let pattern = "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?(?:\\+[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: value,
                  range: NSRange(value.startIndex..., in: value)
              ),
              match.range.location != NSNotFound,
              let majorRange = Range(match.range(at: 1), in: value),
              let minorRange = Range(match.range(at: 2), in: value),
              let patchRange = Range(match.range(at: 3), in: value),
              let major = Int(value[majorRange]),
              let minor = Int(value[minorRange]),
              let patch = Int(value[patchRange])
        else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
        if match.range(at: 4).location != NSNotFound,
           let prereleaseRange = Range(match.range(at: 4), in: value) {
            let identifiers = value[prereleaseRange].split(separator: ".").map(String.init)
            guard identifiers.allSatisfy({ identifier in
                !identifier.allSatisfy(\.isNumber)
                    || identifier == "0"
                    || !identifier.hasPrefix("0")
            }) else {
                return nil
            }
            prerelease = identifiers
        } else {
            prerelease = nil
        }
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case let (.some(left), .some(right)):
            for index in 0..<min(left.count, right.count) {
                if left[index] == right[index] { continue }
                let leftNumber = Int(left[index])
                let rightNumber = Int(right[index])
                switch (leftNumber, rightNumber) {
                case let (.some(a), .some(b)): return a < b
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return left[index] < right[index]
                }
            }
            return left.count < right.count
        }
    }
}

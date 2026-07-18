import Foundation
import HabitatCore

struct CompatibilitySelectors: Codable, Equatable, Sendable {
    let sidebar: String
    let mainSurface: String
    let composer: String
    let threadScroll: String
    let popover: String
    let header: String
    let homeMarker: String
    let appShell: String?
    let homeContent: String?
    let homeSuggestions: String?
    let selectedNavigation: String?
    let taskTranscript: String?
    let userMessageSurface: String?
    let messageSurface: String?
    let codeSurface: String?
    let toolSurfaces: [String]?
    let sidebarResizeChrome: String?
    let topFade: String?
    let bottomFade: String?
    let stickyBand: String?
    let composerContext: String?

    var allSelectors: [String] {
        [
            sidebar,
            mainSurface,
            composer,
            threadScroll,
            popover,
            header,
            homeMarker,
            appShell,
            homeContent,
            homeSuggestions,
            selectedNavigation,
            taskTranscript,
            userMessageSurface,
            messageSurface,
            codeSurface,
            sidebarResizeChrome,
            topFade,
            bottomFade,
            stickyBand,
            composerContext,
        ].compactMap { $0 } + (toolSurfaces ?? [])
    }
}

struct CompatibilityProfile: Codable, Equatable, Sendable {
    let id: String
    let minimumVersion: String
    let maximumVersionExclusive: String
    let selectors: CompatibilitySelectors
}

enum CompatibilityProfileError: Error, Equatable {
    case unsupportedSchema
    case malformedVersion
    case unsafeSelector(String)
    case duplicateProfile(String)
    case invalidVersionRange(String)
    case unorderedProfiles(String, String)
    case overlappingProfiles(String, String)
}

struct CompatibilityProfileStore {
    private let profiles: [CompatibilityProfile]

    init(data: Data) throws {
        let document = try JSONDecoder().decode(CompatibilityDocument.self, from: data)
        guard document.schemaVersion == 1 else {
            throw CompatibilityProfileError.unsupportedSchema
        }
        var identifiers: Set<String> = []
        var previousRange: (id: String, minimum: BridgeVersion, maximum: BridgeVersion)?
        for profile in document.profiles {
            guard identifiers.insert(profile.id).inserted else {
                throw CompatibilityProfileError.duplicateProfile(profile.id)
            }
            guard let minimum = BridgeVersion(profile.minimumVersion),
                  let maximum = BridgeVersion(profile.maximumVersionExclusive)
            else {
                throw CompatibilityProfileError.malformedVersion
            }
            guard minimum < maximum else {
                throw CompatibilityProfileError.invalidVersionRange(profile.id)
            }
            if let previousRange {
                guard previousRange.minimum < minimum else {
                    throw CompatibilityProfileError.unorderedProfiles(
                        previousRange.id,
                        profile.id
                    )
                }
                guard previousRange.maximum <= minimum else {
                    throw CompatibilityProfileError.overlappingProfiles(
                        previousRange.id,
                        profile.id
                    )
                }
            }
            previousRange = (profile.id, minimum, maximum)
            for selector in profile.selectors.allSelectors {
                try Self.validateSelector(selector)
            }
        }
        profiles = document.profiles
    }

    static func bundled() throws -> CompatibilityProfileStore {
        guard let url = PackagedResourceLocator.url(
            forResource: "compatibility",
            withExtension: "json",
            subdirectory: "Resources",
            packageBundleName: "CodexHabitat_CodexHabitatThemeBridge.bundle"
        ) else {
            throw CompatibilityProfileError.unsupportedSchema
        }
        return try CompatibilityProfileStore(data: Data(contentsOf: url))
    }

    func profile(forVersion value: String) -> CompatibilityProfile? {
        guard let version = BridgeVersion(value) else { return nil }
        return profiles.first { profile in
            guard let minimum = BridgeVersion(profile.minimumVersion),
                  let maximum = BridgeVersion(profile.maximumVersionExclusive)
            else {
                return false
            }
            return minimum <= version && version < maximum
        }
    }

    private static func validateSelector(_ selector: String) throws {
        let lowercased = selector.lowercased()
        let forbiddenFragments = [
            "*", ",", "script", ":has(", ":contains(", ":nth-",
            "http://", "https://", "javascript:", "url(",
        ]
        let contentAttributePattern =
            "\\[(aria-label|title|href|src|value|placeholder|alt)([~|^$*]?=|\\])"
        guard !selector.isEmpty,
              selector.count <= 160,
              !selector.contains("{") && !selector.contains("}"),
              !selector.contains(";") && !selector.contains("@"),
              forbiddenFragments.allSatisfy({ !lowercased.contains($0) }),
              lowercased.range(
                of: contentAttributePattern,
                options: .regularExpression
              ) == nil,
              selector.range(
                of: "^[A-Za-z0-9._#\\[\\]=\"'():/ >+~-]+$",
                options: .regularExpression
              ) != nil
        else {
            throw CompatibilityProfileError.unsafeSelector(selector)
        }
    }
}

private struct CompatibilityDocument: Decodable {
    let schemaVersion: Int
    let profiles: [CompatibilityProfile]
}

private struct BridgeVersion: Comparable {
    let parts: [Int]

    init?(_ value: String) {
        let rawParts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...4).contains(rawParts.count),
              rawParts.allSatisfy({ part in
                  !part.isEmpty
                      && part.allSatisfy(\.isNumber)
                      && (part == "0" || !part.hasPrefix("0"))
              })
        else {
            return nil
        }
        parts = rawParts.compactMap { Int($0) }
        guard parts.count == rawParts.count else { return nil }
    }

    static func < (lhs: BridgeVersion, rhs: BridgeVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}

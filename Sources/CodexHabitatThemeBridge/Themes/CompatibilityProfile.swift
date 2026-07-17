import Foundation
import HabitatCore

struct CompatibilitySelectors: Codable, Equatable, Sendable {
    let sidebar: String
    let mainSurface: String
    let composer: String
    let threadScroll: String
    let popover: String
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
}

struct CompatibilityProfileStore {
    private let profiles: [CompatibilityProfile]

    init(data: Data) throws {
        let document = try JSONDecoder().decode(CompatibilityDocument.self, from: data)
        guard document.schemaVersion == 1 else {
            throw CompatibilityProfileError.unsupportedSchema
        }
        var identifiers: Set<String> = []
        for profile in document.profiles {
            guard identifiers.insert(profile.id).inserted else {
                throw CompatibilityProfileError.duplicateProfile(profile.id)
            }
            guard BridgeVersion(profile.minimumVersion) != nil,
                  BridgeVersion(profile.maximumVersionExclusive) != nil
            else {
                throw CompatibilityProfileError.malformedVersion
            }
            for selector in [
                profile.selectors.sidebar,
                profile.selectors.mainSurface,
                profile.selectors.composer,
                profile.selectors.threadScroll,
                profile.selectors.popover,
            ] {
                try Self.validateSelector(selector)
            }
        }
        profiles = document.profiles
    }

    static func bundled() throws -> CompatibilityProfileStore {
        guard let url = PackagedResourceLocator.url(
            forResource: "compatibility",
            withExtension: "json",
            subdirectory: "Resources"
        ) ?? Bundle.module.url(
            forResource: "compatibility",
            withExtension: "json",
            subdirectory: "Resources"
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
        guard !selector.isEmpty,
              selector.count <= 160,
              !selector.contains("{") && !selector.contains("}"),
              !selector.contains(";") && !selector.contains("@"),
              !selector.lowercased().contains("url("),
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

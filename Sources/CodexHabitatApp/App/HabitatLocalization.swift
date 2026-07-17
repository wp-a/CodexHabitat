import Foundation

struct HabitatLocalization: Sendable {
    let resolvedLanguage: String
    private let strings: [String: String]

    init(localeIdentifier: String = Locale.preferredLanguages.first ?? "en") {
        resolvedLanguage = Self.resolveLanguage(localeIdentifier)
        strings = (try? Self.catalog(language: resolvedLanguage))
            ?? (try? Self.catalog(language: "en"))
            ?? [:]
    }

    func text(_ key: String) -> String {
        strings[key] ?? key
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: text(key),
            locale: Locale(identifier: resolvedLanguage),
            arguments: arguments
        )
    }

    static func catalog(language: String) throws -> [String: String] {
        let resolved = resolveLanguage(language)
        let fileManager = FileManager.default
        for root in resourceRoots() {
            let url = root
                .appending(path: "\(resolved).lproj", directoryHint: .isDirectory)
                .appending(path: "Localizable.strings")
            guard fileManager.isReadableFile(atPath: url.path) else { continue }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard let catalog = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: String] else {
                throw CocoaError(.propertyListReadCorrupt)
            }
            return catalog
        }
        throw CocoaError(.fileNoSuchFile)
    }

    static func formatPlaceholders(in value: String) -> [String] {
        let pattern = #"%(?:\d+\$)?[-+0 #']*(?:\d+|\*)?(?:\.(?:\d+|\*))?[hlLzjtq]*[@diuoxXfFeEgGaAcCsSp]"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: value) else { return nil }
            return String(value[swiftRange])
        }
    }

    private static func resolveLanguage(_ identifier: String) -> String {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if normalized == "zh" || normalized.hasPrefix("zh-hans") || normalized.hasPrefix("zh-cn") {
            return "zh-Hans"
        }
        return "en"
    }

    private static func resourceRoots() -> [URL] {
        var roots: [URL] = []
        if let root = Bundle.main.resourceURL {
            roots.append(root)
            roots.append(root.appending(path: "Resources", directoryHint: .isDirectory))
        }
        roots.append(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Resources", directoryHint: .isDirectory)
        )
        return roots
    }
}

enum L10n {
    static let current = HabitatLocalization()

    static func text(_ key: String) -> String {
        current.text(key)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: current.text(key),
            locale: Locale(identifier: current.resolvedLanguage),
            arguments: arguments
        )
    }
}

import CryptoKit
import Foundation

public enum PetdexClientError: Error, Equatable, Sendable {
    case insecureURL
    case disallowedHost(String)
    case invalidResponse
    case responseTooLarge(limit: Int)
    case invalidCatalog
    case networkUnavailable
    case unverifiedPackage
    case hashMismatch
}

public struct PetdexClient: Sendable {
    public static let defaultCatalogURL = URL(string: "https://petdex.dev/api/manifest")!

    public static func live() -> PetdexClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        let delegate = PetdexRedirectDelegate(
            allowedHosts: ["petdex.dev", "assets.petdex.dev"]
        )
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        return PetdexClient(session: session)
    }

    private let session: URLSession
    private let catalogURL: URL
    private let maxCatalogBytes: Int
    private let maxPackageBytes: Int
    private let catalogHosts: Set<String>
    private let assetHosts: Set<String>

    public init(
        session: URLSession = .shared,
        catalogURL: URL = PetdexClient.defaultCatalogURL,
        maxCatalogBytes: Int = 4 * 1024 * 1024,
        maxPackageBytes: Int = 50 * 1024 * 1024,
        catalogHosts: Set<String> = ["petdex.dev", "assets.petdex.dev"],
        assetHosts: Set<String> = ["assets.petdex.dev"]
    ) {
        self.session = session
        self.catalogURL = catalogURL
        self.maxCatalogBytes = maxCatalogBytes
        self.maxPackageBytes = maxPackageBytes
        self.catalogHosts = catalogHosts
        self.assetHosts = assetHosts
    }

    public func fetchCatalog() async throws -> [MarketplacePet] {
        try validateURL(catalogURL, allowedHosts: ["petdex.dev"])
        var request = URLRequest(url: catalogURL, timeoutInterval: 8)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await data(for: request, limit: maxCatalogBytes)
        guard let finalURL = response.url else { throw PetdexClientError.invalidResponse }
        try validateURL(finalURL, allowedHosts: catalogHosts)

        let document: CatalogDocument
        do {
            document = try JSONDecoder().decode(CatalogDocument.self, from: data)
        } catch {
            throw PetdexClientError.invalidCatalog
        }
        guard !document.generatedAt.isEmpty,
              document.total == document.pets.count,
              document.pets.count <= 5_000
        else {
            throw PetdexClientError.invalidCatalog
        }

        var identifiers: Set<String> = []
        return try document.pets.map { entry in
            guard Self.matches(entry.slug, "^[a-z0-9][a-z0-9-]{0,62}$"),
                  identifiers.insert(entry.slug).inserted,
                  Self.isValidText(entry.displayName, maximum: 100),
                  Self.isValidText(entry.kind, maximum: 64)
            else {
                throw PetdexClientError.invalidCatalog
            }
            try validateURL(entry.spritesheetURL, allowedHosts: assetHosts)
            try validateURL(entry.petJSONURL, allowedHosts: assetHosts)
            if let packageURL = entry.zipURL {
                try validateURL(packageURL, allowedHosts: assetHosts)
            }

            let sourceURL = entry.sourceURL
                ?? URL(string: "https://petdex.dev/pets/\(entry.slug)")!
            try validateDisplayURL(sourceURL)
            let license = try entry.license.map { value in
                guard Self.matches(value.spdx, "^[A-Za-z0-9][A-Za-z0-9.+-]{0,63}$") else {
                    throw PetdexClientError.invalidCatalog
                }
                try validateDisplayURL(value.url)
                return MarketplaceLicense(spdx: value.spdx, url: value.url)
            }
            if let digest = entry.packageSHA256,
               !Self.matches(digest, "^[0-9a-f]{64}$") {
                throw PetdexClientError.invalidCatalog
            }
            if let contentID = entry.contentID,
               !Self.matches(contentID, "^[a-z0-9]+([.-][a-z0-9]+)*$") {
                throw PetdexClientError.invalidCatalog
            }

            return MarketplacePet(
                id: entry.slug,
                displayName: entry.displayName,
                kind: entry.kind,
                author: entry.submittedBy.flatMap {
                    Self.isValidText($0, maximum: 100) ? $0 : nil
                },
                previewURL: entry.spritesheetURL,
                metadataURL: entry.petJSONURL,
                packageURL: entry.zipURL,
                sourceURL: sourceURL,
                license: license,
                packageSHA256: entry.packageSHA256,
                contentID: entry.contentID
            )
        }
    }

    public func installConfirmed(
        _ pet: MarketplacePet,
        using installer: sending PackageInstaller,
        replacing: Bool = false
    ) async throws -> InstalledPackage {
        guard let packageURL = pet.packageURL,
              let expectedDigest = pet.packageSHA256,
              let expectedID = pet.contentID,
              pet.license != nil
        else {
            throw PetdexClientError.unverifiedPackage
        }
        try validateURL(packageURL, allowedHosts: assetHosts)
        guard Self.matches(expectedDigest, "^[0-9a-f]{64}$"),
              Self.matches(expectedID, "^[a-z0-9]+([.-][a-z0-9]+)*$")
        else {
            throw PetdexClientError.unverifiedPackage
        }

        var request = URLRequest(url: packageURL, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("application/zip", forHTTPHeaderField: "Accept")
        request.setValue("https://petdex.dev/", forHTTPHeaderField: "Referer")
        let (archiveData, response) = try await data(for: request, limit: maxPackageBytes)
        guard let finalURL = response.url else { throw PetdexClientError.invalidResponse }
        try validateURL(finalURL, allowedHosts: assetHosts)
        let actualDigest = SHA256.hash(data: archiveData)
            .map { String(format: "%02x", $0) }
            .joined()
        guard actualDigest == expectedDigest else {
            throw PetdexClientError.hashMismatch
        }

        let temporaryRoot = FileManager.default.temporaryDirectory.appending(
            path: "CodexHabitat-Petdex-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let archiveURL = temporaryRoot.appending(path: "download.habitat-pack")
        try archiveData.write(to: archiveURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: archiveURL.path
        )
        return try installer.install(
            archiveURL,
            replacing: replacing,
            expectedID: expectedID
        )
    }

    private func data(for request: URLRequest, limit: Int) async throws -> (Data, HTTPURLResponse) {
        do {
            try Task.checkCancellation()
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode)
            else {
                throw PetdexClientError.invalidResponse
            }
            if response.expectedContentLength > Int64(limit) || data.count > limit {
                throw PetdexClientError.responseTooLarge(limit: limit)
            }
            return (data, response)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where [
            .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
            .cannotFindHost, .dnsLookupFailed, .timedOut,
        ].contains(error.code) {
            throw PetdexClientError.networkUnavailable
        }
    }

    private func validateURL(_ url: URL, allowedHosts: Set<String>) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw PetdexClientError.insecureURL
        }
        let host = url.host?.lowercased() ?? ""
        guard allowedHosts.contains(host),
              url.user == nil,
              url.password == nil,
              url.port == nil
        else {
            throw PetdexClientError.disallowedHost(host)
        }
    }

    private func validateDisplayURL(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https",
              !(url.host ?? "").isEmpty,
              url.user == nil,
              url.password == nil
        else {
            throw PetdexClientError.invalidCatalog
        }
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isValidText(_ value: String, maximum: Int) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maximum && !value.contains("\0")
    }
}

private struct CatalogDocument: Decodable {
    let generatedAt: String
    let total: Int
    let pets: [CatalogPet]
}

private struct CatalogPet: Decodable {
    let slug: String
    let displayName: String
    let kind: String
    let submittedBy: String?
    let spritesheetURL: URL
    let petJSONURL: URL
    let zipURL: URL?
    let sourceURL: URL?
    let packageSHA256: String?
    let contentID: String?
    let license: CatalogLicense?

    private enum CodingKeys: String, CodingKey {
        case slug, displayName, kind, submittedBy, zipURL = "zipUrl", sourceURL = "sourceUrl"
        case spritesheetURL = "spritesheetUrl"
        case petJSONURL = "petJsonUrl"
        case packageSHA256 = "packageSha256"
        case contentID = "contentId"
        case license
    }
}

private struct CatalogLicense: Decodable {
    let spdx: String
    let url: URL
}

private final class PetdexRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let allowedHosts: Set<String>

    init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              url.scheme?.lowercased() == "https",
              allowedHosts.contains(url.host?.lowercased() ?? ""),
              url.user == nil,
              url.password == nil,
              url.port == nil
        else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

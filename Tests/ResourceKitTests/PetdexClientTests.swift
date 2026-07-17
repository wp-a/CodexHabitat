import CryptoKit
import Foundation
import Testing
@testable import ResourceKit

@Suite(.serialized)
struct PetdexClientTests {
    @Test
    func fixtureDecodesVerifiedAndLegacyEntriesWithLicenseDisclosure() async throws {
        let data = try Data(contentsOf: Bundle.module.url(
            forResource: "petdex-manifest",
            withExtension: "json",
            subdirectory: "Fixtures"
        )!)
        let session = stubSession { request in
            #expect(request.url == URL(string: "https://petdex.dev/api/manifest"))
            #expect(request.timeoutInterval == 8)
            return .success(data, url: request.url!)
        }
        let client = PetdexClient(session: session)

        let catalog = try await client.fetchCatalog()

        #expect(catalog.count == 2)
        #expect(catalog[0].id == "codie")
        #expect(catalog[0].licenseLabel == "MIT")
        #expect(catalog[0].isInstallable)
        #expect(catalog[1].licenseLabel == "License not declared")
        #expect(!catalog[1].isInstallable)
        #expect(catalog[1].sourceURL == URL(string: "https://petdex.dev/pets/legacy-pet"))
    }

    @Test
    func catalogEndpointMustUseHTTPSAndTheExactAllowedHost() async {
        let session = stubSession { _ in
            Issue.record("An invalid endpoint must be rejected before transport")
            return .failure(URLError(.badURL))
        }

        await #expect(throws: PetdexClientError.insecureURL) {
            _ = try await PetdexClient(
                session: session,
                catalogURL: URL(string: "http://petdex.dev/api/manifest")!
            ).fetchCatalog()
        }
        await #expect(throws: PetdexClientError.disallowedHost("mirror.example")) {
            _ = try await PetdexClient(
                session: session,
                catalogURL: URL(string: "https://mirror.example/api/manifest")!
            ).fetchCatalog()
        }
    }

    @Test
    func redirectedCatalogResponsesCannotEscapeTheHostAllowlist() async {
        let session = stubSession { _ in
            .success(Data("{\"generatedAt\":\"now\",\"total\":0,\"pets\":[]}".utf8),
                     url: URL(string: "https://evil.example/catalog.json")!)
        }
        let client = PetdexClient(session: session)

        await #expect(throws: PetdexClientError.disallowedHost("evil.example")) {
            _ = try await client.fetchCatalog()
        }
    }

    @Test
    func catalogResponseSizeIsBoundedBeforeDecoding() async {
        let session = stubSession { request in
            .success(
                Data(repeating: 0x20, count: 65),
                url: request.url!,
                headers: ["Content-Length": "65"]
            )
        }
        let client = PetdexClient(session: session, maxCatalogBytes: 64)

        await #expect(throws: PetdexClientError.responseTooLarge(limit: 64)) {
            _ = try await client.fetchCatalog()
        }
    }

    @Test
    func offlineAndCancellationRemainDistinctStates() async {
        let offlineSession = stubSession { _ in .failure(URLError(.notConnectedToInternet)) }
        let offlineClient = PetdexClient(session: offlineSession)
        await #expect(throws: PetdexClientError.networkUnavailable) {
            _ = try await offlineClient.fetchCatalog()
        }

        let cancelledSession = stubSession { _ in .failure(URLError(.cancelled)) }
        let cancelledClient = PetdexClient(session: cancelledSession)
        await #expect(throws: CancellationError.self) {
            _ = try await cancelledClient.fetchCatalog()
        }
    }

    @Test
    func packageHashMismatchIsRejectedBeforeInstallerRuns() async throws {
        let package = Data("tampered package".utf8)
        let session = stubSession { request in .success(package, url: request.url!) }
        let client = PetdexClient(session: session)
        let pet = verifiedPet(sha256: String(repeating: "0", count: 64))
        let library = temporaryDirectory("PetdexHash")
        defer { try? FileManager.default.removeItem(at: library) }

        await #expect(throws: PetdexClientError.hashMismatch) {
            _ = try await client.installConfirmed(
                pet,
                using: PackageInstaller(libraryRoot: library, runtimeVersion: "1.0.0")
            )
        }
        #expect(!FileManager.default.fileExists(atPath: library.path))
    }

    @Test
    func packageContentIDMustMatchBeforePublication() async throws {
        let archiveURL = try makeTestArchive([
            TestArchiveEntry(path: "habitat.json", data: try minimalManifestData(id: "studio.example.safe-pack")),
            TestArchiveEntry(path: "preview.png", data: try testPNG()),
            TestArchiveEntry(path: "LICENSE", data: Data("MIT".utf8)),
        ])
        defer { try? FileManager.default.removeItem(at: archiveURL) }
        let package = try Data(contentsOf: archiveURL)
        let digest = SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined()
        let session = stubSession { request in .success(package, url: request.url!) }
        let client = PetdexClient(session: session)
        let pet = verifiedPet(sha256: digest, contentID: "studio.example.another-pack")
        let library = temporaryDirectory("PetdexIdentity")
        defer { try? FileManager.default.removeItem(at: library) }

        await #expect(
            throws: PackageInstallationError.contentIDMismatch(
                expected: "studio.example.another-pack",
                actual: "studio.example.safe-pack"
            )
        ) {
            _ = try await client.installConfirmed(
                pet,
                using: PackageInstaller(libraryRoot: library, runtimeVersion: "1.0.0")
            )
        }
        #expect(try publishedPackageDirectoriesForPetdex(in: library).isEmpty)
    }

    @Test
    func unverifiedLegacyEntryCannotStartADownload() async {
        let session = stubSession { _ in
            Issue.record("Unverified entries must not reach transport")
            return .failure(URLError(.badURL))
        }
        let client = PetdexClient(session: session)
        let library = temporaryDirectory("PetdexUnverified")
        defer { try? FileManager.default.removeItem(at: library) }
        let pet = MarketplacePet(
            id: "legacy-pet",
            displayName: "Legacy Pet",
            kind: "character",
            author: "Artist",
            previewURL: URL(string: "https://assets.petdex.dev/pets/legacy/sprite.webp")!,
            metadataURL: URL(string: "https://assets.petdex.dev/pets/legacy/petjson.json")!,
            packageURL: URL(string: "https://assets.petdex.dev/pets/legacy/zip.zip"),
            sourceURL: URL(string: "https://petdex.dev/pets/legacy-pet")!,
            license: nil,
            packageSHA256: nil,
            contentID: nil
        )

        await #expect(throws: PetdexClientError.unverifiedPackage) {
            _ = try await client.installConfirmed(
                pet,
                using: PackageInstaller(libraryRoot: library, runtimeVersion: "1.0.0")
            )
        }
    }

    private func verifiedPet(
        sha256: String,
        contentID: String = "studio.example.safe-pack"
    ) -> MarketplacePet {
        MarketplacePet(
            id: "safe-pack",
            displayName: "Safe Pack",
            kind: "original",
            author: "Habitat",
            previewURL: URL(string: "https://assets.petdex.dev/pets/safe/sprite.webp")!,
            metadataURL: URL(string: "https://assets.petdex.dev/pets/safe/petjson.json")!,
            packageURL: URL(string: "https://assets.petdex.dev/pets/safe/pack.zip")!,
            sourceURL: URL(string: "https://github.com/example/safe-pack")!,
            license: MarketplaceLicense(
                spdx: "MIT",
                url: URL(string: "https://github.com/example/safe-pack/blob/main/LICENSE")!
            ),
            packageSHA256: sha256,
            contentID: contentID
        )
    }
}

private enum StubResult {
    case success(Data, url: URL, status: Int = 200, headers: [String: String] = [:])
    case failure(Error)
}

private final class PetdexURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> StubResult)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        switch handler(request) {
        case let .success(data, url, status, headers):
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func stubSession(handler: @escaping (URLRequest) -> StubResult) -> URLSession {
    PetdexURLProtocolStub.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [PetdexURLProtocolStub.self]
    return URLSession(configuration: configuration)
}

private func temporaryDirectory(_ name: String) -> URL {
    FileManager.default.temporaryDirectory.appending(
        path: "\(name)-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
}

private func publishedPackageDirectoriesForPetdex(in library: URL) throws -> [URL] {
    guard FileManager.default.fileExists(atPath: library.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(
        at: library,
        includingPropertiesForKeys: nil
    ).filter { !$0.lastPathComponent.hasPrefix(".") }
}

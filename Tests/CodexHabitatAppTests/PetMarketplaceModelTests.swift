import Foundation
import ResourceKit
import Testing
@testable import CodexHabitatApp

@MainActor
struct PetMarketplaceModelTests {
    @Test
    func browsingIsOptInAndLoadsOnlyAfterExplicitEnablement() async {
        var fetchCount = 0
        let model = PetMarketplaceModel(
            fetchCatalog: {
                fetchCount += 1
                return [marketplacePet(id: "codie"), marketplacePet(id: "boba")]
            },
            install: { _ in }
        )

        #expect(model.state == .disabled)
        #expect(fetchCount == 0)

        await model.enableBrowsing()

        #expect(fetchCount == 1)
        #expect(model.state == .loaded)
        #expect(model.pets.map(\.id) == ["codie", "boba"])
    }

    @Test
    func searchMatchesNameAuthorKindAndLicense() async {
        let model = PetMarketplaceModel(
            fetchCatalog: {
                [marketplacePet(id: "codie", name: "Codie", author: "Habitat", kind: "robot")]
            },
            install: { _ in }
        )
        await model.enableBrowsing()

        model.searchText = "robot"
        #expect(model.filteredPets.map(\.id) == ["codie"])
        model.searchText = "apache"
        #expect(model.filteredPets.isEmpty)
    }

    @Test
    func offlineCatalogLeavesAnExplicitRetryableState() async {
        let model = PetMarketplaceModel(
            fetchCatalog: { throw PetdexClientError.networkUnavailable },
            install: { _ in }
        )

        await model.enableBrowsing()

        #expect(model.state == .offline)
        #expect(model.pets.isEmpty)
    }

    @Test
    func selectingInstallOnlyRecordsIntentUntilConfirmation() async {
        var installedIDs: [String] = []
        let pet = marketplacePet(id: "codie")
        let model = PetMarketplaceModel(
            fetchCatalog: { [pet] },
            install: { installedIDs.append($0.id) }
        )
        await model.enableBrowsing()

        model.requestInstallation(of: pet)
        #expect(model.pendingInstallation == pet)
        #expect(installedIDs.isEmpty)

        await model.confirmInstallation()
        #expect(installedIDs == ["codie"])
        #expect(model.pendingInstallation == nil)
        #expect(model.lastInstalledID == "codie")
    }

    @Test
    func unverifiedEntriesCannotReachTheInstaller() async {
        var installCount = 0
        let unverified = marketplacePet(id: "legacy", verified: false)
        let model = PetMarketplaceModel(
            fetchCatalog: { [unverified] },
            install: { _ in installCount += 1 }
        )
        await model.enableBrowsing()

        model.requestInstallation(of: unverified)
        await model.confirmInstallation()

        #expect(model.pendingInstallation == nil)
        #expect(installCount == 0)
        #expect(model.installationState == .unverified)
    }
}

private func marketplacePet(
    id: String,
    name: String? = nil,
    author: String? = "Codex Habitat",
    kind: String = "original",
    verified: Bool = true
) -> MarketplacePet {
    MarketplacePet(
        id: id,
        displayName: name ?? id.capitalized,
        kind: kind,
        author: author,
        previewURL: URL(string: "https://assets.petdex.dev/pets/\(id)/sprite.webp")!,
        metadataURL: URL(string: "https://assets.petdex.dev/pets/\(id)/petjson.json")!,
        packageURL: URL(string: "https://assets.petdex.dev/pets/\(id)/pack.zip")!,
        sourceURL: URL(string: "https://github.com/example/\(id)")!,
        license: verified
            ? MarketplaceLicense(
                spdx: "MIT",
                url: URL(string: "https://github.com/example/\(id)/blob/main/LICENSE")!
            )
            : nil,
        packageSHA256: verified ? String(repeating: "a", count: 64) : nil,
        contentID: verified ? "studio.example.\(id)" : nil
    )
}

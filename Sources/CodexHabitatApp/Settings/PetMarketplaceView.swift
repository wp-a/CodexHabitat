import Foundation
import ResourceKit
import SwiftUI

enum PetMarketplaceLoadState: Equatable {
    case disabled
    case loading
    case loaded
    case offline
    case failed
}

enum PetMarketplaceInstallationState: Equatable {
    case idle
    case installing(String)
    case installed(String)
    case unverified
    case failed
}

@MainActor
final class PetMarketplaceModel: ObservableObject {
    typealias FetchCatalog = @MainActor () async throws -> [MarketplacePet]
    typealias Install = @MainActor (MarketplacePet) async throws -> Void

    @Published private(set) var state = PetMarketplaceLoadState.disabled
    @Published private(set) var pets: [MarketplacePet] = []
    @Published var searchText = ""
    @Published var pendingInstallation: MarketplacePet?
    @Published private(set) var installationState = PetMarketplaceInstallationState.idle
    @Published private(set) var lastInstalledID: String?

    private let fetchCatalog: FetchCatalog
    private let install: Install

    var filteredPets: [MarketplacePet] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return pets }
        return pets.filter { pet in
            [pet.displayName, pet.author ?? "", pet.kind, pet.licenseLabel]
                .contains { $0.lowercased().contains(query) }
        }
    }

    init(
        fetchCatalog: @escaping FetchCatalog,
        install: @escaping Install
    ) {
        self.fetchCatalog = fetchCatalog
        self.install = install
    }

    static func live(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PetMarketplaceModel {
        let client = PetdexClient.live()
        let libraryRoot: URL
        if let configuredRoot = environment["CODEX_HABITAT_HOME"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !configuredRoot.isEmpty {
            libraryRoot = URL(fileURLWithPath: configuredRoot, isDirectory: true)
                .appending(path: "Library", directoryHint: .isDirectory)
        } else {
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
            libraryRoot = applicationSupport
                .appending(path: "Codex Habitat", directoryHint: .isDirectory)
                .appending(path: "Library", directoryHint: .isDirectory)
        }
        return PetMarketplaceModel(
            fetchCatalog: { try await client.fetchCatalog() },
            install: { pet in
                let installer = PackageInstaller(
                    libraryRoot: libraryRoot,
                    runtimeVersion: "1.0.0"
                )
                _ = try await client.installConfirmed(pet, using: installer)
            }
        )
    }

    func enableBrowsing() async {
        await loadCatalog()
    }

    func reload() async {
        guard state != .disabled else { return }
        await loadCatalog()
    }

    func disableBrowsing() {
        pets = []
        searchText = ""
        pendingInstallation = nil
        installationState = .idle
        state = .disabled
    }

    func requestInstallation(of pet: MarketplacePet) {
        pendingInstallation = pet
    }

    func cancelInstallation() {
        pendingInstallation = nil
    }

    func confirmInstallation() async {
        guard let pet = pendingInstallation else { return }
        pendingInstallation = nil
        guard pet.isInstallable else {
            installationState = .unverified
            return
        }
        installationState = .installing(pet.id)
        do {
            try await install(pet)
            lastInstalledID = pet.id
            installationState = .installed(pet.id)
        } catch is CancellationError {
            installationState = .idle
        } catch {
            installationState = .failed
        }
    }

    private func loadCatalog() async {
        state = .loading
        do {
            pets = try await fetchCatalog()
            state = .loaded
        } catch is CancellationError {
            state = .disabled
        } catch PetdexClientError.networkUnavailable {
            pets = []
            state = .offline
        } catch {
            pets = []
            state = .failed
        }
    }
}

struct PetMarketplaceView: View {
    @ObservedObject var model: PetMarketplaceModel
    private let columns = [GridItem(.adaptive(minimum: 178, maximum: 230), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch model.state {
            case .disabled:
                disabledState
            case .loading:
                ProgressView("Loading Petdex catalog...")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 250)
            case .offline:
                unavailableState(
                    title: "Petdex Is Offline",
                    description: "Your installed pets still work. Reconnect and try the catalog again."
                )
            case .failed:
                unavailableState(
                    title: "Catalog Unavailable",
                    description: "Petdex returned data Habitat could not safely use."
                )
            case .loaded:
                catalog
            }
        }
        .alert(
            "Install \(model.pendingInstallation?.displayName ?? "pet")?",
            isPresented: Binding(
                get: { model.pendingInstallation != nil },
                set: { if !$0 { model.cancelInstallation() } }
            ),
            presenting: model.pendingInstallation
        ) { _ in
            Button("Cancel", role: .cancel, action: model.cancelInstallation)
            Button("Install") {
                Task { await model.confirmInstallation() }
            }
        } message: { pet in
            Text("Author: \(pet.author ?? "Unknown")\nLicense: \(pet.licenseLabel)\nSource: \(pet.sourceURL.absoluteString)")
        }
    }

    private var disabledState: some View {
        ContentUnavailableView {
            Label("Browse Petdex", systemImage: "square.grid.2x2")
        } description: {
            Text("Catalog access is optional. Habitat sends no account, thread, prompt, or usage data.")
        } actions: {
            Button("Enable Browsing") {
                Task { await model.enableBrowsing() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("pets.marketplace.enable")
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private func unavailableState(title: String, description: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "wifi.slash")
        } description: {
            Text(description)
        } actions: {
            HStack {
                Button("Try Again") {
                    Task { await model.reload() }
                }
                Button("Stop Browsing", action: model.disableBrowsing)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var catalog: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField("Search pets, creators, or licenses", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("pets.marketplace.search")
                Text("\(model.filteredPets.count)")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 34, alignment: .trailing)
                Button {
                    Task { await model.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh Petdex")
                .accessibilityLabel("Refresh Petdex")
                Button(action: model.disableBrowsing) {
                    Image(systemName: "network.slash")
                }
                .buttonStyle(.borderless)
                .help("Stop browsing")
                .accessibilityLabel("Stop browsing")
            }

            installationStatus

            if model.filteredPets.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(model.filteredPets) { pet in
                        MarketplacePetCard(
                            pet: pet,
                            isInstalling: model.installationState == .installing(pet.id),
                            install: { model.requestInstallation(of: pet) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var installationStatus: some View {
        switch model.installationState {
        case let .installing(id):
            Label("Verifying and installing \(id)...", systemImage: "arrow.down.circle")
                .foregroundStyle(.secondary)
        case let .installed(id):
            Label("\(id) installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .unverified:
            Label("This entry is missing a license, content ID, or SHA-256 checksum.", systemImage: "lock.shield")
                .foregroundStyle(.orange)
        case .failed:
            Label("The package failed verification or installation.", systemImage: "xmark.octagon")
                .foregroundStyle(.red)
        case .idle:
            EmptyView()
        }
    }
}

private struct MarketplacePetCard: View {
    let pet: MarketplacePet
    let isInstalling: Bool
    let install: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(colorForKind)
                    .frame(width: 34, height: 34)
                    .background(colorForKind.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    Text(pet.author ?? "Unknown creator")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Text(pet.kind.capitalized)
                Text("/")
                    .foregroundStyle(.tertiary)
                Text(pet.licenseLabel)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            HStack {
                Link(destination: pet.sourceURL) {
                    Image(systemName: "arrow.up.right.square")
                }
                .help("Open source")
                .accessibilityLabel("Open source for \(pet.displayName)")
                Spacer()
                if pet.isInstallable {
                    Button(action: install) {
                        if isInstalling {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                    }
                    .disabled(isInstalling)
                    .help("Review and install")
                    .accessibilityLabel("Install \(pet.displayName)")
                } else {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.secondary)
                        .help("Browse only: verification metadata is missing")
                        .accessibilityLabel("Installation unavailable")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.09), lineWidth: 1)
        }
    }

    private var colorForKind: Color {
        switch pet.kind.lowercased() {
        case "animal": .green
        case "character": .orange
        case "robot": .cyan
        default: .accentColor
        }
    }
}

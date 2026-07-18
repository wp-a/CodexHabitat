import PetRuntime
import SwiftUI

actor PetThumbnailStore {
    typealias Loader = @Sendable (PetLibraryEntry) -> CGImage?

    static let shared = PetThumbnailStore { pet in
        guard let spritesheetURL = pet.spritesheetURL, let atlas = pet.atlas else {
            return nil
        }
        return SpriteSheetRenderer.frame(
            contentsOf: spritesheetURL,
            atlas: atlas,
            row: 0,
            column: 0
        )
    }

    private enum CachedResult {
        case image(CGImage)
        case missing
    }

    private struct Key: Hashable, Sendable {
        let packageURL: URL
        let spritesheetURL: URL?
        let pixelWidth: Int?
        let pixelHeight: Int?
        let columns: Int?
        let rows: Int?

        init(pet: PetLibraryEntry) {
            packageURL = pet.packageURL
            spritesheetURL = pet.spritesheetURL
            pixelWidth = pet.atlas?.pixelWidth
            pixelHeight = pet.atlas?.pixelHeight
            columns = pet.atlas?.columns
            rows = pet.atlas?.rows
        }
    }

    private let loader: Loader
    private var cache: [Key: CachedResult] = [:]

    init(loader: @escaping Loader) {
        self.loader = loader
    }

    func image(for pet: PetLibraryEntry) -> CGImage? {
        let key = Key(pet: pet)
        if let cached = cache[key] {
            switch cached {
            case let .image(image):
                return image
            case .missing:
                return nil
            }
        }
        guard let image = loader(pet) else {
            cache[key] = .missing
            return nil
        }
        cache[key] = .image(image)
        return image
    }
}

struct PetsSettingsView: View {
    private enum Source: String, CaseIterable, Identifiable {
        case local = "Installed"
        case petdex = "Petdex"

        var id: String { rawValue }
    }

    @ObservedObject var model: HabitatAppModel
    @StateObject private var marketplaceModel = PetMarketplaceModel.live()
    @State private var source = Source.local
    private let columns = [GridItem(.adaptive(minimum: 142, maximum: 180), spacing: 12)]

    var body: some View {
        SettingsPage(
            "Pets",
            subtitle: "Use validated local companions or optionally browse Petdex"
        ) {
            Picker("Pet source", selection: $source) {
                ForEach(Source.allCases) { source in
                    Text(L10n.text(source.rawValue)).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("pets.source")

            if source == .local {
                localPets
            } else {
                PetMarketplaceView(model: marketplaceModel)
            }
        }
        .onChange(of: source) { _, newValue in
            if newValue == .local {
                model.refreshResources()
            }
        }
        .onChange(of: marketplaceModel.lastInstalledID) { _, installedID in
            if installedID != nil {
                model.refreshResources()
            }
        }
        .resourceReplacementConfirmation(model: model)
    }

    @ViewBuilder
    private var localPets: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(L10n.format("%d available", model.validPets.count))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: importPack) {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .help("Import Habitat pack")
                .accessibilityLabel("Import Habitat pack")
                .accessibilityIdentifier("pets.import-pack")
                Button(action: model.refreshResources) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh pets")
                .accessibilityLabel("Refresh pets")
                .accessibilityIdentifier("pets.refresh")
            }

            ResourceOperationStatusView(state: model.resourceOperationState)

            if model.validPets.isEmpty {
                ContentUnavailableView(
                    "No Valid Pets",
                    systemImage: "pawprint",
                    description: Text("Habitat will keep running while the local pet library is empty.")
                )
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(model.validPets, id: \.packageURL) { pet in
                        PetChoiceCard(
                            pet: pet,
                            isSelected: model.settings.selectedPetID == pet.manifest?.id,
                            action: { model.selectPet(pet.manifest?.id) }
                        )
                    }
                }
            }
        }
    }

    private func importPack() {
        guard let url = ResourcePackPanels.chooseImport() else { return }
        Task { await model.importResourcePackage(from: url) }
    }
}

struct PetChoiceCard: View {
    let pet: PetLibraryEntry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                PetThumbnail(pet: pet)
                    .frame(height: 82)
                Text(pet.manifest?.displayName ?? pet.packageURL.lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 124)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.09), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pet.manifest?.displayName ?? "Pet")
        .accessibilityValue(L10n.text(isSelected ? "Selected" : "Not selected"))
        .accessibilityIdentifier("pets.choice.\(pet.manifest?.id ?? "unknown")")
    }
}

private struct PetThumbnail: View {
    let pet: PetLibraryEntry
    @State private var idleFrame: CGImage?

    var body: some View {
        Group {
            if let image = idleFrame {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: pet.packageURL) {
            let image = await PetThumbnailStore.shared.image(for: pet)
            guard !Task.isCancelled else { return }
            idleFrame = image
        }
    }
}

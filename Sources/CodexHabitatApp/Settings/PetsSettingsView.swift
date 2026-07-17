import PetRuntime
import SwiftUI

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
                    Text(source.rawValue).tag(source)
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
                model.refreshPets()
            }
        }
    }

    @ViewBuilder
    private var localPets: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("\(model.validPets.count) available")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: model.refreshPets) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh pets")
                .accessibilityLabel("Refresh pets")
                .accessibilityIdentifier("pets.refresh")
            }

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
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("pets.choice.\(pet.manifest?.id ?? "unknown")")
    }
}

private struct PetThumbnail: View {
    let pet: PetLibraryEntry

    var body: some View {
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

    private var idleFrame: CGImage? {
        guard let spritesheetURL = pet.spritesheetURL, let atlas = pet.atlas else { return nil }
        return SpriteSheetRenderer(contentsOf: spritesheetURL, atlas: atlas)
            .frame(PetFrame(animation: .idle, row: 0, column: 0))
    }
}

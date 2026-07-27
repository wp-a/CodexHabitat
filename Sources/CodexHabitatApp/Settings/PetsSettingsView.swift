import HabitatCore
import PetRuntime
import SwiftUI

struct PetThumbnailRequestKey: Hashable, Sendable {
    let packageURL: URL
    let spritesheetURL: URL?
    let fileSize: Int?
    let modificationDate: Date?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let columns: Int?
    let rows: Int?

    init(pet: PetLibraryEntry) {
        packageURL = pet.packageURL
        spritesheetURL = pet.spritesheetURL
        if let spritesheetURL = pet.spritesheetURL {
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: spritesheetURL.path
            )
            fileSize = (attributes?[.size] as? NSNumber)?.intValue
            modificationDate = attributes?[.modificationDate] as? Date
        } else {
            fileSize = nil
            modificationDate = nil
        }
        pixelWidth = pet.atlas?.pixelWidth
        pixelHeight = pet.atlas?.pixelHeight
        columns = pet.atlas?.columns
        rows = pet.atlas?.rows
    }
}

struct PetThumbnailLoadIdentity: Hashable {
    let packageURL: URL?
    let spritesheetURL: URL?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let columns: Int?
    let rows: Int?
    let retryGeneration: Int

    init(pet: PetLibraryEntry?, retryGeneration: Int) {
        packageURL = pet?.packageURL
        spritesheetURL = pet?.spritesheetURL
        pixelWidth = pet?.atlas?.pixelWidth
        pixelHeight = pet?.atlas?.pixelHeight
        columns = pet?.atlas?.columns
        rows = pet?.atlas?.rows
        self.retryGeneration = retryGeneration
    }
}

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

    private let loader: Loader
    private var cache: [PetThumbnailRequestKey: CachedResult] = [:]
    private struct InFlight {
        let token: UUID
        let task: Task<CGImage?, Never>
    }
    private var inFlight: [PetThumbnailRequestKey: InFlight] = [:]

    init(loader: @escaping Loader) {
        self.loader = loader
    }

    func image(for pet: PetLibraryEntry) async -> CGImage? {
        let key = PetThumbnailRequestKey(pet: pet)
        if let cached = cache[key] {
            switch cached {
            case let .image(image):
                return image
            case .missing:
                return nil
            }
        }
        if let existing = inFlight[key] {
            return await existing.task.value
        }
        let loader = self.loader
        let token = UUID()
        let task = Task.detached(priority: .userInitiated) {
            loader(pet)
        }
        inFlight[key] = InFlight(token: token, task: task)
        let loadedImage = await task.value
        guard inFlight[key]?.token == token else { return loadedImage }
        inFlight[key] = nil
        guard let image = loadedImage else {
            cache[key] = .missing
            return nil
        }
        cache[key] = .image(image)
        return image
    }

    func invalidate(_ pet: PetLibraryEntry) {
        let packageURL = pet.packageURL
        cache = cache.filter { $0.key.packageURL != packageURL }
        let matchingKeys = inFlight.keys.filter { $0.packageURL == packageURL }
        for key in matchingKeys {
            inFlight.removeValue(forKey: key)?.task.cancel()
        }
    }
}

struct PetPreviewPresentationState {
    enum Status: Equatable, Sendable {
        case idle
        case loading
        case ready
        case failed
    }

    private(set) var selectedPetID: String?
    private(set) var displayedImage: CGImage?
    private(set) var status = Status.idle
    private var request = 0

    mutating func select(petID: String) -> Int {
        request += 1
        selectedPetID = petID
        status = .loading
        return request
    }

    mutating func complete(petID: String, request: Int, image: CGImage?) {
        guard selectedPetID == petID, self.request == request else { return }
        if let image {
            displayedImage = image
            status = .ready
        } else {
            status = .failed
        }
    }
}

struct PetRendererRecoveryState: Equatable, Sendable {
    let selectedPetID: String?
    let failure: PetRendererFailure?

    var inlineMessage: String? {
        guard failure?.petID == selectedPetID else { return nil }
        return failure?.message
    }
}

@MainActor
struct PetRendererRecoveryCoordinator {
    let invalidatePreview: (PetLibraryEntry) async -> Void
    let retryRenderer: () -> Void

    func retry(pet: PetLibraryEntry) async {
        await invalidatePreview(pet)
        retryRenderer()
    }
}

struct PetsSettingsView: View {
    private enum Source: String, CaseIterable, Identifiable {
        case local = "Installed"
        case petdex = "Petdex"

        var id: String { rawValue }
    }

    @ObservedObject var model: HabitatAppModel
    @ObservedObject var desktopController: HabitatDesktopController
    @StateObject private var marketplaceModel = PetMarketplaceModel.live()
    @State private var source = Source.local
    @State private var showsCompactInspector = false

    var body: some View {
        SettingsPage(
            "Pets",
            subtitle: "Use validated local companions or optionally browse Petdex",
            scrollBehavior: .pageOwned
        ) {
            VStack(spacing: 0) {
                toolbar
                Divider()

                if source == .local {
                    localPets
                } else {
                    PetMarketplaceView(model: marketplaceModel)
                        .padding(24)
                }
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

    private var toolbar: some View {
        HStack(spacing: HabitatDesignMetrics.spaceM) {
            Picker(L10n.text("Pet source"), selection: $source) {
                ForEach(Source.allCases) { source in
                    Text(L10n.text(source.rawValue)).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .accessibilityIdentifier("pets.source")

            Text(L10n.format("%d available", model.validPets.count))
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: importPack) {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)
            .help(L10n.text("Import Habitat pack"))
            .accessibilityLabel(L10n.text("Import Habitat pack"))
            .accessibilityIdentifier("pets.import-pack")

            Button(action: model.refreshResources) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(L10n.text("Refresh pets"))
            .accessibilityLabel(L10n.text("Refresh pets"))
            .accessibilityIdentifier("pets.refresh")
        }
        .padding(.horizontal, HabitatDesignMetrics.spaceXL)
        .frame(minHeight: 52)
    }

    @ViewBuilder
    private var localPets: some View {
        VStack(spacing: 0) {
            ResourceOperationStatusView(state: model.resourceOperationState)
                .padding(.horizontal, HabitatDesignMetrics.spaceXL)

            if model.validPets.isEmpty {
                emptyLibrary
            } else {
                GeometryReader { proxy in
                    if proxy.size.width >= 760 {
                        HStack(spacing: 0) {
                            petResourceList
                                .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
                            Divider()
                            PetPreviewPane(
                                pet: selectedPet,
                                rendererError: rendererRecoveryState.inlineMessage,
                                onRetry: recoverPet
                            )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            Divider()
                            PetBehaviorInspector(model: model, pet: selectedPet)
                                .frame(width: 270)
                        }
                    } else {
                        compactWorkspace
                    }
                }
            }
        }
    }

    private var selectedPet: PetLibraryEntry? {
        model.validPets.first { $0.manifest?.id == model.settings.selectedPetID }
            ?? model.validPets.first
    }

    private var petResourceList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.text("Pet Library"))
                .font(.headline)
                .padding(.horizontal, HabitatDesignMetrics.spaceL)
                .frame(minHeight: 44, alignment: .leading)
            Divider()
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.validPets, id: \.packageURL) { pet in
                        PetResourceRow(
                            pet: pet,
                            isSelected: model.settings.selectedPetID == pet.manifest?.id,
                            action: { model.selectPet(pet.manifest?.id) }
                        )
                    }
                }
                .padding(HabitatDesignMetrics.spaceS)
            }
        }
        .background(.background.opacity(0.35))
    }

    private var compactWorkspace: some View {
        VStack(spacing: 0) {
            petResourceList
                .frame(height: 176)
            Divider()
            PetPreviewPane(
                pet: selectedPet,
                rendererError: rendererRecoveryState.inlineMessage,
                onRetry: recoverPet
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Text(L10n.text("Behavior"))
                    .font(.headline)
                Spacer()
                Button {
                    showsCompactInspector = true
                } label: {
                    Label(L10n.text("Edit Behavior"), systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("pets.behavior.open")
            }
            .padding(.horizontal, HabitatDesignMetrics.spaceL)
            .frame(minHeight: 52)
        }
        .sheet(isPresented: $showsCompactInspector) {
            PetBehaviorInspector(model: model, pet: selectedPet)
                .frame(minWidth: 320, minHeight: 440)
                .padding(HabitatDesignMetrics.spaceXL)
        }
    }

    private var emptyLibrary: some View {
        VStack(spacing: HabitatDesignMetrics.spaceM) {
            Label(L10n.text("No Valid Pets"), systemImage: "pawprint")
                .font(.title3.weight(.semibold))
            Text(L10n.text("Habitat will keep running while the local pet library is empty."))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: HabitatDesignMetrics.spaceS) {
                Button(action: importPack) {
                    Label(L10n.text("Import Pack"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    source = .petdex
                } label: {
                    Label(L10n.text("Browse Petdex"), systemImage: "square.grid.2x2")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(HabitatDesignMetrics.spaceXXL)
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private var rendererRecoveryState: PetRendererRecoveryState {
        PetRendererRecoveryState(
            selectedPetID: model.settings.selectedPetID,
            failure: desktopController.petLoadFailure
        )
    }

    @MainActor
    private func recoverPet(_ pet: PetLibraryEntry) async {
        let coordinator = PetRendererRecoveryCoordinator(
            invalidatePreview: { pet in
                await PetThumbnailStore.shared.invalidate(pet)
            },
            retryRenderer: desktopController.retryPetRendererLoad
        )
        await coordinator.retry(pet: pet)
    }

    private func importPack() {
        guard let url = ResourcePackPanels.chooseImport() else { return }
        Task { await model.importResourcePackage(from: url) }
    }
}

private struct PetResourceRow: View {
    let pet: PetLibraryEntry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HabitatDesignMetrics.spaceM) {
                PetThumbnail(pet: pet)
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.manifest?.displayName ?? pet.packageURL.lastPathComponent)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(pet.manifest?.description ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, HabitatDesignMetrics.spaceS)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .habitatSelectedStyle(isSelected, radius: HabitatDesignMetrics.cardRadius)
        .accessibilityLabel(pet.manifest?.displayName ?? L10n.text("Pet"))
        .accessibilityValue(L10n.text(isSelected ? "Selected" : "Not selected"))
        .accessibilityHint(L10n.text("Select pet"))
        .accessibilityIdentifier("pets.choice.\(pet.manifest?.id ?? "unknown")")
    }
}

private struct PetPreviewPane: View {
    let pet: PetLibraryEntry?
    let rendererError: String?
    let onRetry: (PetLibraryEntry) async -> Void
    @State private var presentation = PetPreviewPresentationState()
    @State private var retryGeneration = 0

    var body: some View {
        VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceL) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pet?.manifest?.displayName ?? L10n.text("Preview"))
                    .font(.title2.weight(.semibold))
                Text(pet?.manifest?.description ?? "")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ZStack {
                RoundedRectangle(cornerRadius: HabitatDesignMetrics.previewRadius)
                    .fill(.quaternary.opacity(0.45))
                if let image = presentation.displayedImage {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .padding(HabitatDesignMetrics.spaceXXL)
                } else if presentation.status == .loading {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1.45, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if presentation.status == .loading, presentation.displayedImage != nil {
                    ProgressView(L10n.text("Loading pet artwork…"))
                        .controlSize(.small)
                        .padding(8)
                        .background(.regularMaterial, in: Capsule())
                        .padding()
                }
            }

            if presentation.status == .failed || rendererError != nil, let pet {
                HStack(spacing: HabitatDesignMetrics.spaceS) {
                    Label {
                        Text(rendererError ?? L10n.text("Unable to load pet artwork"))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.text("Retry")) {
                        Task {
                            await onRetry(pet)
                            retryGeneration += 1
                        }
                    }
                    .accessibilityIdentifier("pets.preview.retry")
                }
            }
        }
        .padding(HabitatDesignMetrics.spaceXL)
        .task(id: requestID) {
            guard let pet, let petID = pet.manifest?.id else { return }
            let request = presentation.select(petID: petID)
            let image = await PetThumbnailStore.shared.image(for: pet)
            guard !Task.isCancelled else { return }
            presentation.complete(petID: petID, request: request, image: image)
        }
    }

    private var requestID: PetThumbnailLoadIdentity {
        PetThumbnailLoadIdentity(pet: pet, retryGeneration: retryGeneration)
    }
}

private struct PetBehaviorInspector: View {
    @ObservedObject var model: HabitatAppModel
    let pet: PetLibraryEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceXL) {
                Text(L10n.text("Behavior"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceS) {
                    HStack {
                        Text(L10n.text("Scale"))
                        Spacer()
                        Text(model.settings.scale, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { model.settings.scale },
                            set: { model.setScale($0) }
                        ),
                        in: 0.75...1.5,
                        step: 0.05
                    )
                    .accessibilityIdentifier("pets.behavior.scale")
                    .accessibilityLabel(L10n.text("Scale"))
                    .accessibilityValue(scaleAccessibilityValue)
                }

                Picker(
                    L10n.text("Motion"),
                    selection: Binding(
                        get: { model.settings.reduceMotion },
                        set: { model.setReduceMotion($0) }
                    )
                ) {
                    Text(L10n.text("System")).tag(ReduceMotionPreference.system)
                    Text(L10n.text("Reduced")).tag(ReduceMotionPreference.reduce)
                    Text(L10n.text("Full")).tag(ReduceMotionPreference.full)
                }
                .pickerStyle(.segmented)

                Toggle(
                    L10n.text("Click through the overlay"),
                    isOn: Binding(
                        get: { model.settings.clickThrough },
                        set: { model.setClickThrough($0) }
                    )
                )
                Toggle(
                    L10n.text("Lock overlay position"),
                    isOn: Binding(
                        get: { model.settings.positionLocked },
                        set: { model.setPositionLocked($0) }
                    )
                )
                .disabled(model.settings.clickThrough)

                Divider()

                VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceS) {
                    inspectorValue("Sprite version", value: pet?.manifest.map {
                        String($0.effectiveSpriteVersion)
                    } ?? "—")
                    inspectorValue("Frame size", value: pet?.atlas.map {
                        "\($0.cellWidth) × \($0.cellHeight)"
                    } ?? "—")
                    inspectorValue("Atlas", value: pet?.atlas.map {
                        "\($0.columns) × \($0.rows)"
                    } ?? "—")
                }
            }
            .padding(HabitatDesignMetrics.spaceL)
        }
        .background(.background.opacity(0.35))
    }

    private var scaleAccessibilityValue: String {
        model.settings.scale.formatted(.percent.precision(.fractionLength(0)))
    }

    private func inspectorValue(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.text(label))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.caption)
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
        .accessibilityLabel(pet.manifest?.displayName ?? L10n.text("Pet"))
        .accessibilityValue(L10n.text(isSelected ? "Selected" : "Not selected"))
        .accessibilityIdentifier("pets.choice.\(pet.manifest?.id ?? "unknown")")
    }
}

private struct PetThumbnail: View {
    private enum Phase {
        case loading
        case ready
        case failed
    }

    let pet: PetLibraryEntry
    @State private var idleFrame: CGImage?
    @State private var phase = Phase.loading

    var body: some View {
        Group {
            if let image = idleFrame {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else if phase == .loading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if phase == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel(L10n.text("Unable to load pet artwork"))
            }
        }
        .task(id: PetThumbnailLoadIdentity(pet: pet, retryGeneration: 0)) {
            phase = .loading
            let image = await PetThumbnailStore.shared.image(for: pet)
            guard !Task.isCancelled else { return }
            idleFrame = image
            phase = image == nil ? .failed : .ready
        }
    }
}

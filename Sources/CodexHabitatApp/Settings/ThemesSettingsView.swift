import ImageIO
import ResourceKit
import SwiftUI

actor ThemePreviewStore {
    typealias Loader = @Sendable (URL) -> CGImage?

    static let shared = ThemePreviewStore { url in
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 480,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private enum CachedResult {
        case image(CGImage)
        case missing
    }

    private struct Key: Hashable, Sendable {
        let url: URL
        let fileSize: Int?
        let modificationDate: Date?

        init(url: URL) {
            self.url = url
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = (attributes?[.size] as? NSNumber)?.intValue
            modificationDate = attributes?[.modificationDate] as? Date
        }
    }

    private let loader: Loader
    private var cache: [Key: CachedResult] = [:]

    init(loader: @escaping Loader) {
        self.loader = loader
    }

    func image(at url: URL?) -> CGImage? {
        guard let url else { return nil }
        let key = Key(url: url)
        if let cached = cache[key] {
            switch cached {
            case let .image(image):
                return image
            case .missing:
                return nil
            }
        }

        let staleKeys = cache.keys.filter { $0.url == url }
        for staleKey in staleKeys {
            cache.removeValue(forKey: staleKey)
        }
        guard let image = loader(url) else {
            cache[key] = .missing
            return nil
        }
        cache[key] = .image(image)
        return image
    }
}

struct ThemesSettingsView: View {
    @ObservedObject var model: HabitatAppModel
    @State private var packageIDToRemove: String?
    @State private var themeStudioModel: ThemeStudioModel?
    @State private var selectedFilter: ThemeGalleryFilter
    @State private var searchText = ""
    private let opensThemeStudioForVisualQA: Bool
    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 12)]

    init(
        model: HabitatAppModel,
        visualQAOptions: HabitatVisualQALaunchOptions = .disabled
    ) {
        self.model = model
        _selectedFilter = State(initialValue: visualQAOptions.themeFilter)
        opensThemeStudioForVisualQA = visualQAOptions.opensThemeStudio
    }

    var body: some View {
        SettingsPage(
            "Themes",
            subtitle: "Native Habitat palettes independent from Codex theming"
        ) {
            HStack(spacing: 10) {
                Text(L10n.format("%d available", model.availableThemes.count))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: openThemeStudio) {
                    Label("Create Theme", systemImage: "plus")
                }
                .accessibilityIdentifier("themes.create")
                Button(action: importPack) {
                    Label("Import Pack", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("themes.import-pack")
                Button(action: model.refreshResources) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh resource library")
                .accessibilityLabel("Refresh resource library")
            }

            ResourceOperationStatusView(state: model.resourceOperationState)

            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal) {
                    Picker("Theme category", selection: $selectedFilter) {
                        ForEach(ThemeGalleryFilter.allCases) { filter in
                            Text(L10n.text(filter.title)).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize(horizontal: true, vertical: false)
                    .labelsHidden()
                }
                .scrollIndicators(.hidden)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L10n.text("Search themes"), text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .help(L10n.text("Clear search"))
                        .accessibilityLabel(L10n.text("Clear search"))
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                }
            }

            if filteredThemes.isEmpty {
                emptyGallery
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(filteredThemes) { theme in
                        ThemeChoiceCard(
                            theme: theme,
                            isSelected: model.settings.selectedThemeID == theme.id,
                            action: { model.selectTheme(theme.id) },
                            editAction: model.installedPackages.contains(where: {
                                $0.id == theme.id && $0.manifest.theme != nil
                            })
                                ? { openThemeStudio(editingThemeID: theme.id) }
                                : nil
                        )
                    }
                }
            }

            if !model.installedPackages.isEmpty {
                Divider()
                SettingsGroup("Installed Packs") {
                    VStack(spacing: 0) {
                        ForEach(Array(model.installedPackages.enumerated()), id: \.element.id) { index, package in
                            installedPackageRow(package)
                            if index < model.installedPackages.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .task {
            guard opensThemeStudioForVisualQA, themeStudioModel == nil else { return }
            await Task.yield()
            openThemeStudio()
        }
        .resourceReplacementConfirmation(model: model)
        .sheet(item: $themeStudioModel) { studio in
            ThemeStudioView(model: studio, onSaved: themeSaved)
        }
        .confirmationDialog(
            "Remove this Habitat pack?",
            isPresented: Binding(
                get: { packageIDToRemove != nil },
                set: { if !$0 { packageIDToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Pack", role: .destructive) {
                guard let packageIDToRemove else { return }
                self.packageIDToRemove = nil
                Task { await model.uninstallResourcePackage(id: packageIDToRemove) }
            }
            Button("Cancel", role: .cancel) { packageIDToRemove = nil }
        } message: {
            Text("Pets and themes supplied by this pack will be removed from Habitat. Codex files are not changed.")
        }
    }

    private var filteredThemes: [HabitatThemeDescriptor] {
        ThemeGalleryQuery.filter(
            model.availableThemes,
            by: selectedFilter,
            search: searchText
        )
    }

    private var emptyGallery: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedFilter == .custom ? "paintpalette" : "magnifyingglass")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            Text(L10n.text(selectedFilter == .custom && searchText.isEmpty
                ? "No custom themes"
                : "No matching themes"))
                .font(.headline)
            if selectedFilter == .custom && searchText.isEmpty {
                Button(action: openThemeStudio) {
                    Label(L10n.text("Create Theme"), systemImage: "plus")
                }
            } else {
                Button(action: { searchText = "" }) {
                    Label(L10n.text("Clear search"), systemImage: "xmark.circle")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .accessibilityIdentifier("themes.empty")
    }

    private func installedPackageRow(_ package: InstalledPackage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(Color(habitatHex: package.manifest.colors.accent))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(package.manifest.name)
                    .font(.body.weight(.medium))
                Text("\(package.manifest.author) · \(package.version) · \(package.manifest.license.spdx)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { export(package) }) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .help("Export pack")
            .accessibilityLabel(L10n.format("Export %@", package.manifest.name))
            Button(role: .destructive, action: { packageIDToRemove = package.id }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove pack")
            .accessibilityLabel(L10n.format("Remove %@", package.manifest.name))
        }
        .padding(.vertical, 10)
    }

    private func importPack() {
        guard let url = ResourcePackPanels.chooseImport() else { return }
        Task { await model.importResourcePackage(from: url) }
    }

    private func openThemeStudio() {
        guard let studio = model.makeThemeStudioModel() else { return }
        themeStudioModel = studio
    }

    private func openThemeStudio(editingThemeID: String) {
        guard let studio = model.makeThemeStudioModel(editingThemeID: editingThemeID) else { return }
        themeStudioModel = studio
    }

    private func themeSaved(id: String, pairedPetID: String?) {
        model.refreshResources()
        model.setThemePetPairing(themeID: id, petID: pairedPetID)
        model.selectTheme(id)
        themeStudioModel = nil
    }

    private func export(_ package: InstalledPackage) {
        guard let url = ResourcePackPanels.chooseExport(for: package) else { return }
        Task { await model.exportResourcePackage(id: package.id, to: url) }
    }
}

struct ThemeChoiceCard: View {
    let theme: HabitatThemeDescriptor
    let isSelected: Bool
    let action: () -> Void
    var editAction: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 10) {
                    ThemeTreatmentPreview(
                        model: ThemeTreatmentPreviewModel(theme: theme),
                        imageURL: theme.backgroundURL ?? theme.previewURL,
                        symbol: theme.symbol
                    )
                    HStack {
                        HStack(spacing: 5) {
                            ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        Spacer()
                        Text(L10n.text(theme.category.localizationKey))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(L10n.text(theme.name))
                        .font(.body.weight(.semibold))
                    Text(L10n.text(theme.detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 224, alignment: .topLeading)
                .background(
                    isSelected ? palette[0].opacity(0.09) : Color.primary.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? palette[0] : Color.primary.opacity(0.09), lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text(theme.name))
            .accessibilityValue(L10n.text(isSelected ? "Selected" : "Not selected"))
            .accessibilityIdentifier("themes.choice.\(theme.id)")

            if let editAction {
                Button(action: editAction) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Edit theme")
                .accessibilityLabel(L10n.format("Edit %@", L10n.text(theme.name)))
                .padding(8)
            }
        }
    }

    private var palette: [Color] {
        [
            Color(habitatHex: theme.accentHex),
            Color(habitatHex: theme.secondaryHex),
            Color(habitatHex: theme.highlightHex),
            Color(habitatHex: theme.attentionHex),
            Color(habitatHex: theme.errorHex),
        ]
    }
}

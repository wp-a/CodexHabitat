import ImageIO
import HabitatCore
import ResourceKit
import SwiftUI

struct ThemePreviewRequestKey: Equatable, Hashable, Sendable {
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

    private let loader: Loader
    private var cache: [ThemePreviewRequestKey: CachedResult] = [:]

    init(loader: @escaping Loader) {
        self.loader = loader
    }

    func image(at url: URL?) -> CGImage? {
        guard let url else { return nil }
        let key = ThemePreviewRequestKey(url: url)
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

    func invalidate(url: URL) {
        let matchingKeys = cache.keys.filter { $0.url == url }
        for key in matchingKeys {
            cache.removeValue(forKey: key)
        }
    }
}

struct ThemesSettingsView: View {
    @ObservedObject var model: HabitatAppModel
    @ObservedObject private var bridge = ThemeBridgeIntegrationModel.shared
    @State private var packageIDToRemove: String?
    @State private var themeStudioModel: ThemeStudioModel?
    @State private var libraryState: ThemeLibraryState
    @State private var confirmsCodexApply = false
    @State private var showsCompactInspector = false
    private let opensThemeStudioForVisualQA: Bool
    private let columns = [
        GridItem(.flexible(minimum: 150, maximum: 224), spacing: 12),
        GridItem(.flexible(minimum: 150, maximum: 224), spacing: 12),
    ]

    init(
        model: HabitatAppModel,
        visualQAOptions: HabitatVisualQALaunchOptions = .disabled
    ) {
        self.model = model
        var initialState = ThemeLibraryState(previewedThemeID: model.settings.selectedThemeID)
        initialState.category = visualQAOptions.themeFilter
        _libraryState = State(initialValue: initialState)
        opensThemeStudioForVisualQA = visualQAOptions.opensThemeStudio
    }

    var body: some View {
        SettingsPage(
            "Themes",
            subtitle: "Browse local themes and explicitly apply a compatible choice",
            scrollBehavior: .pageOwned
        ) {
            VStack(spacing: 0) {
                toolbar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background { HabitatSurface(role: .toolbar) }
                Divider()

                ResourceOperationStatusView(state: model.resourceOperationState)
                    .padding(.horizontal, 16)

                if bridge.state == .failed {
                    Label(L10n.text(bridge.statusText), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .accessibilityIdentifier("themes.bridge.failure")
                }

                GeometryReader { proxy in
                    if proxy.size.width >= 720 {
                        HStack(spacing: 0) {
                            gallery
                            Divider()
                            themeInspector
                                .frame(width: 316)
                                .background { HabitatSurface(role: .inspector) }
                        }
                    } else {
                        gallery
                    }
                }
            }
        }
        .task {
            await bridge.refresh()
            model.setThemeBridgeEnabled(bridge.state == .active)
        }
        .task {
            guard opensThemeStudioForVisualQA, themeStudioModel == nil else { return }
            await Task.yield()
            openThemeStudio()
        }
        .onChange(of: model.availableThemes.map(\.id)) { _, identifiers in
            if libraryState.previewedThemeID.map(Set(identifiers).contains) != true {
                libraryState.select(model.settings.selectedThemeID)
            }
        }
        .resourceReplacementConfirmation(model: model)
        .sheet(item: $themeStudioModel) { studio in
            ThemeStudioView(model: studio, onSaved: themeSaved)
        }
        .sheet(isPresented: $showsCompactInspector) {
            themeInspector
                .frame(minWidth: 340, idealWidth: 380, minHeight: 500)
                .background { HabitatSurface(role: .inspector) }
        }
        .alert(
            bridge.state == .active
                ? "Switch Codex to the selected theme?"
                : "Restart Codex with the selected theme?",
            isPresented: $confirmsCodexApply
        ) {
            Button("Cancel", role: .cancel) {
                libraryState.clearPendingApply()
            }
            Button(bridge.state == .active ? "Switch Theme" : "Restart and Apply") {
                applyPendingTheme()
            }
            .disabled(!bridge.canApply)
        } message: {
            Text(bridge.state == .active
                ? "The current bridge theme will be replaced without restarting Codex."
                : "Codex will close and reopen on a local debugging port. Unsaved composer text may be lost. Restore closes the port and returns the official appearance.")
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

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchField.frame(minWidth: 170, idealWidth: 220, maxWidth: 280)
                scopePicker
                categoryMenu
                Spacer(minLength: 0)
                toolbarActions
            }
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    searchField
                    categoryMenu
                    toolbarActions
                }
                HStack(spacing: 8) {
                    scopePicker
                    Spacer(minLength: 0)
                    Button(action: { showsCompactInspector = true }) {
                        Label(L10n.text("Theme details"), systemImage: "sidebar.right")
                    }
                    .controlSize(.small)
                    .accessibilityIdentifier("themes.compact-inspector")
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L10n.text("Search themes"), text: $libraryState.searchText)
                .textFieldStyle(.plain)
            if !libraryState.searchText.isEmpty {
                Button(action: { libraryState.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help(L10n.text("Clear search"))
                .accessibilityLabel(L10n.text("Clear search"))
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private var scopePicker: some View {
        Picker("Theme collection", selection: $libraryState.scope) {
            ForEach(ThemeLibraryScope.allCases) { scope in
                Text(L10n.text(scope.title)).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityIdentifier("themes.scope")
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(ThemeGalleryFilter.allCases) { category in
                Button {
                    libraryState.category = category
                } label: {
                    if libraryState.category == category {
                        Label(L10n.text(category.title), systemImage: "checkmark")
                    } else {
                        Text(L10n.text(category.title))
                    }
                }
            }
        } label: {
            Label(L10n.text(libraryState.category.title), systemImage: "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(L10n.text("Theme category"))
        .accessibilityIdentifier("themes.category")
    }

    private var toolbarActions: some View {
        HStack(spacing: 4) {
            toolbarButton("square.and.arrow.down", help: "Import Pack", action: importPack)
                .accessibilityIdentifier("themes.import-pack")
            toolbarButton("plus", help: "Create Theme", action: openThemeStudio)
                .accessibilityIdentifier("themes.create")
            toolbarButton("arrow.clockwise", help: "Refresh resource library", action: model.refreshResources)
                .accessibilityIdentifier("themes.refresh")
        }
    }

    private func toolbarButton(
        _ symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .help(L10n.text(help))
        .accessibilityLabel(L10n.text(help))
    }

    private var gallery: some View {
        ScrollView {
            if filteredThemes.isEmpty {
                emptyGallery
                    .padding(16)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(filteredThemes) { theme in
                        ThemeChoiceCard(
                            theme: theme,
                            isSelected: libraryState.previewedThemeID == theme.id,
                            isActive: bridge.state == .active && bridge.activeThemeID == theme.id,
                            isFavorite: model.settings.favoriteThemeIDs.contains(theme.id),
                            action: { selectTheme(theme.id) },
                            favoriteAction: { model.toggleThemeFavorite(theme.id) }
                        )
                    }
                }
                .padding(16)
            }

            if !model.installedPackages.isEmpty {
                DisclosureGroup(L10n.text("Installed Packs")) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.installedPackages.enumerated()), id: \.element.id) { index, package in
                            installedPackageRow(package)
                            if index < model.installedPackages.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .scrollIndicators(.automatic)
        .accessibilityIdentifier("themes.gallery")
    }

    private var themeInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text(selectedTheme.name))
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    Text(L10n.text(selectedTheme.styleFamily.libraryTitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { model.toggleThemeFavorite(selectedTheme.id) }) {
                    Image(systemName: isSelectedThemeFavorite ? "star.fill" : "star")
                }
                .buttonStyle(.borderless)
                .help(L10n.text(isSelectedThemeFavorite ? "Remove from Favorites" : "Add to Favorites"))
                .accessibilityLabel(L10n.text(isSelectedThemeFavorite ? "Remove from Favorites" : "Add to Favorites"))
                if model.isThemeStudioEditableTheme(selectedTheme.id) {
                    Button(action: { openThemeStudio(editingThemeID: selectedTheme.id) }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help(L10n.text("Edit theme"))
                    .accessibilityLabel(L10n.text("Edit theme"))
                }
            }

            Picker("Preview route", selection: $libraryState.previewRoute) {
                Text(L10n.text("Home")).tag(ThemeTreatmentPreviewRoute.home)
                Text(L10n.text("Task")).tag(ThemeTreatmentPreviewRoute.task)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ThemeTreatmentPreview(
                model: ThemeTreatmentPreviewModel(theme: selectedTheme),
                imageURL: selectedTheme.previewURL,
                symbol: selectedTheme.symbol,
                route: libraryState.previewRoute,
                height: 180,
                showsRetryControl: true
            )

            HStack(spacing: 7) {
                ForEach(Array(selectedTheme.palette.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)
                }
            }
            .accessibilityHidden(true)

            Divider()
            inspectorStatusRow(
                "Theme family",
                value: selectedTheme.styleFamily.libraryTitle,
                symbol: "square.3.layers.3d"
            )
            inspectorStatusRow(
                "Codex compatibility",
                value: selectedThemeSupportsBridge ? "Supported" : "Habitat only",
                symbol: selectedThemeSupportsBridge ? "checkmark.shield" : "macwindow"
            )
            inspectorStatusRow(
                "Bridge status",
                value: bridge.statusText,
                symbol: bridge.state == .failed ? "exclamationmark.triangle" : "point.3.connected.trianglepath.dotted"
            )
            if bridge.canRestore {
                inspectorStatusRow(
                    "Restore",
                    value: "Restore available",
                    symbol: "arrow.uturn.backward"
                )
            }
            if isSelectedThemeActive {
                Label(L10n.text("Active in Codex"), systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("themes.inspector.active")
            }

            Spacer(minLength: 0)
            Button(action: requestInspectorApply) {
                Label(L10n.text(isSelectedThemeActive ? "Active in Codex" : "Apply to Codex"), systemImage: "paintbrush")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canApplySelectedTheme)
            .accessibilityIdentifier("themes.apply-to-codex")
        }
        .padding(16)
        .accessibilityIdentifier("themes.inspector")
    }

    private func inspectorStatusRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.text(title))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(L10n.text(value))
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
        }
    }

    private var selectedTheme: HabitatThemeDescriptor {
        model.availableThemes.first { $0.id == libraryState.previewedThemeID }
            ?? model.selectedTheme
    }

    private var selectedThemeSupportsBridge: Bool {
        model.codexBridgeThemeIDs.contains(selectedTheme.id)
    }

    private var isSelectedThemeActive: Bool {
        bridge.state == .active && bridge.activeThemeID == selectedTheme.id
    }

    private var isSelectedThemeFavorite: Bool {
        model.settings.favoriteThemeIDs.contains(selectedTheme.id)
    }

    private var canApplySelectedTheme: Bool {
        bridge.canApply && selectedThemeSupportsBridge && !isSelectedThemeActive
    }

    private var filteredThemes: [HabitatThemeDescriptor] {
        ThemeGalleryQuery.filter(
            model.availableThemes,
            scope: libraryState.scope,
            category: libraryState.category,
            search: libraryState.searchText,
            favoriteThemeIDs: model.settings.favoriteThemeIDs,
            recentThemeIDs: model.settings.recentThemeIDs
        )
    }

    private func selectTheme(_ themeID: String) {
        guard model.availableThemes.contains(where: { $0.id == themeID }) else { return }
        libraryState.select(themeID)
        model.recordRecentlyPreviewedTheme(themeID)
    }

    private func requestInspectorApply() {
        guard canApplySelectedTheme else { return }
        libraryState.requestApply()
        confirmsCodexApply = libraryState.pendingApplyThemeID != nil
    }

    private func applyPendingTheme() {
        guard let themeID = libraryState.pendingApplyThemeID else { return }
        Task {
            await bridge.enable(
                themeID: themeID,
                approvedThemeIDs: model.codexBridgeThemeIDs
            )
            if bridge.activeThemeID == themeID {
                model.selectTheme(themeID)
            }
            model.setThemeBridgeEnabled(bridge.state == .active)
            libraryState.clearPendingApply()
        }
    }

    private var emptyGallery: some View {
        VStack(spacing: 10) {
            Image(systemName: libraryState.category == .custom ? "paintpalette" : "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
            Text(L10n.text(libraryState.category == .custom && libraryState.searchText.isEmpty
                ? "No custom themes"
                : "No matching themes"))
                .font(.headline)
            if libraryState.category == .custom && libraryState.searchText.isEmpty {
                Button(action: openThemeStudio) {
                    Label(L10n.text("Create Theme"), systemImage: "plus")
                }
            } else {
                Button(action: { libraryState.searchText = "" }) {
                    Label(L10n.text("Clear search"), systemImage: "xmark.circle")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .accessibilityIdentifier("themes.empty")
    }

    private func installedPackageRow(_ package: InstalledPackage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .foregroundStyle(Color(habitatHex: package.manifest.colors.accent))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(package.manifest.name)
                    .font(.body.weight(.medium))
                Text("\(package.manifest.author) · \(package.version) · \(package.manifest.license.spdx)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            toolbarButton("square.and.arrow.up", help: "Export pack") { export(package) }
            toolbarButton("trash", help: "Remove pack") { packageIDToRemove = package.id }
        }
        .padding(.vertical, 8)
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
        libraryState.select(id)
        themeStudioModel = nil
    }

    private func export(_ package: InstalledPackage) {
        guard let url = ResourcePackPanels.chooseExport(for: package) else { return }
        Task { await model.exportResourcePackage(id: package.id, to: url) }
    }
}

struct ThemeGalleryPreviewPlan: Equatable, Sendable {
    let imageURL: URL?
    let usesStaticThumbnail: Bool
    let usesBackdropMaterial: Bool

    init(theme: HabitatThemeDescriptor) {
        imageURL = theme.previewURL
        usesStaticThumbnail = true
        usesBackdropMaterial = false
    }
}

struct StaticThemeThumbnail: View {
    let imageURL: URL?
    let symbol: String
    let surfaceHex: String
    let accentHex: String
    let reloadGeneration: Int
    @Binding var retryAvailable: Bool
    @State private var image: CGImage?
    @State private var presentationState = ThemePreviewPresentationState()

    var body: some View {
        ZStack {
            Color(habitatHex: surfaceHex)
            if let image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(habitatHex: accentHex))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .task(id: previewLoadIdentity) {
            let requestID = presentationState.beginRequest()
            retryAvailable = false
            let loadedImage = await ThemePreviewStore.shared.image(at: imageURL)
            guard !Task.isCancelled else { return }
            switch presentationState.complete(
                requestID: requestID,
                succeeded: loadedImage != nil
            ) {
            case .displayImage:
                image = loadedImage
                retryAvailable = false
            case .clearImage:
                image = nil
                retryAvailable = imageURL != nil
            case .ignored:
                break
            }
        }
    }

    private var previewRequestKey: ThemePreviewRequestKey? {
        imageURL.map(ThemePreviewRequestKey.init(url:))
    }

    private var previewLoadIdentity: String {
        let request = previewRequestKey
        return "\(request?.url.path ?? "missing")|\(request?.fileSize ?? -1)|\(request?.modificationDate?.timeIntervalSinceReferenceDate ?? -1)|\(reloadGeneration)"
    }
}

struct ThemeChoiceCard: View {
    let theme: HabitatThemeDescriptor
    let isSelected: Bool
    let isActive: Bool
    let isFavorite: Bool
    let action: () -> Void
    let favoriteAction: (() -> Void)?
    @State private var previewRetryAvailable = false
    @State private var previewReloadGeneration = 0

    init(
        theme: HabitatThemeDescriptor,
        isSelected: Bool,
        isActive: Bool = false,
        isFavorite: Bool = false,
        action: @escaping () -> Void,
        favoriteAction: (() -> Void)? = nil
    ) {
        self.theme = theme
        self.isSelected = isSelected
        self.isActive = isActive
        self.isFavorite = isFavorite
        self.action = action
        self.favoriteAction = favoriteAction
    }

    var body: some View {
        let previewPlan = ThemeGalleryPreviewPlan(theme: theme)
        ZStack(alignment: .center) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 0) {
                    StaticThemeThumbnail(
                        imageURL: previewPlan.imageURL,
                        symbol: theme.symbol,
                        surfaceHex: theme.surfaceHex,
                        accentHex: theme.accentHex,
                        reloadGeneration: previewReloadGeneration,
                        retryAvailable: $previewRetryAvailable
                    )
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.text(theme.name))
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(2)
                                .frame(height: 28, alignment: .topLeading)
                            Text(L10n.text(theme.styleFamily.libraryTitle))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 46)
                }
                .frame(maxWidth: 224, alignment: .topLeading)
                .background(Color.primary.opacity(isSelected ? 0.07 : 0.035))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected
                                ? Color(habitatHex: theme.accentHex)
                                : Color.primary.opacity(0.10),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text(theme.name))
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("themes.choice.\(theme.id)")

            if previewRetryAvailable, previewPlan.imageURL != nil {
                Button(action: retryPreview) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(retryAccessibilityLabel)
                .accessibilityLabel(retryAccessibilityLabel)
                .accessibilityIdentifier("themes.choice.\(theme.id).retry")
                .padding(7)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let favoriteAction {
                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.text(isFavorite ? "Remove from Favorites" : "Add to Favorites"))
                .accessibilityLabel(L10n.text(isFavorite ? "Remove from Favorites" : "Add to Favorites"))
                .padding(7)
            }
        }
        .overlay(alignment: .topLeading) {
            if isActive {
                Label(L10n.text("Active"), systemImage: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .frame(height: 24)
                    .background(.regularMaterial, in: Capsule())
                    .padding(7)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: 224, minHeight: 150, maxHeight: 172, alignment: .top)
    }

    private var accessibilityValue: String {
        [
            L10n.text(isSelected ? "Selected" : "Not selected"),
            L10n.text(isActive ? "Active" : "Inactive"),
            L10n.text(isFavorite ? "Favorite" : "Not favorite"),
        ].joined(separator: ", ")
    }

    private var retryAccessibilityLabel: String {
        L10n.format("Retry %@ preview", L10n.text(theme.name))
    }

    private func retryPreview() {
        guard let imageURL = theme.previewURL else { return }
        Task {
            await ThemePreviewStore.shared.invalidate(url: imageURL)
            guard !Task.isCancelled else { return }
            previewReloadGeneration += 1
        }
    }
}

private extension HabitatThemeDescriptor {
    var palette: [Color] {
        [accentHex, secondaryHex, highlightHex, attentionHex, errorHex]
            .map(Color.init(habitatHex:))
    }
}

extension HabitatThemeStyleFamily {
    var libraryTitle: String {
        switch self {
        case .arcade: "Arcade"
        case .retroMessenger: "Retro Messenger"
        case .greenChat: "Green Chat"
        case .classicDesktop: "Classic Desktop"
        case .gameCinematic: "Game Cinematic"
        case .cozyWorld: "Cozy World"
        case .animeEnergy: "Anime Energy"
        case .fantasyAdventure: "Fantasy Adventure"
        case .pixelWorld: "Pixel World"
        }
    }
}

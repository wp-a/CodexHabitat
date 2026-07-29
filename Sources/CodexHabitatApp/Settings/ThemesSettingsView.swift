import ImageIO
import HabitatCore
import ResourceKit
import SwiftUI

struct ThemePreviewRequestKey: Equatable, Hashable, Sendable {
    let url: URL
    let maximumPixelSize: Int
    let fileSize: Int?
    let modificationDate: Date?

    init(url: URL) {
        self.init(url: url, maximumPixelSize: 480)
    }

    init(url: URL, maximumPixelSize: Int) {
        self.url = url
        self.maximumPixelSize = maximumPixelSize
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        fileSize = (attributes?[.size] as? NSNumber)?.intValue
        modificationDate = attributes?[.modificationDate] as? Date
    }
}

struct ThemePreviewLoadIdentity: Equatable, Hashable, Sendable {
    let url: URL?
    let reloadGeneration: Int
}

actor ThemePreviewStore {
    typealias Loader = @Sendable (ThemePreviewRequestKey) -> CGImage?

    static let shared = ThemePreviewStore { request in
        guard let source = CGImageSourceCreateWithURL(request.url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: request.maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private enum CachedResult {
        case image(CGImage)
        case missing

        var cost: Int {
            switch self {
            case let .image(image):
                let (cost, overflow) = image.bytesPerRow.multipliedReportingOverflow(
                    by: image.height
                )
                return overflow ? .max : max(1, cost)
            case .missing:
                return 1
            }
        }
    }

    private let loader: Loader
    private let maximumCacheCost: Int
    private let maximumCacheEntries: Int
    private var cache: [ThemePreviewRequestKey: CachedResult] = [:]
    private var cacheCost = 0
    private var cacheRecency: [ThemePreviewRequestKey] = []
    private struct InFlight {
        let token: UUID
        let task: Task<CGImage?, Never>
    }
    private var inFlight: [ThemePreviewRequestKey: InFlight] = [:]

    init(
        maximumCacheCost: Int = 96 * 1_024 * 1_024,
        maximumCacheEntries: Int = 128,
        loader: @escaping Loader
    ) {
        self.maximumCacheCost = max(0, maximumCacheCost)
        self.maximumCacheEntries = max(0, maximumCacheEntries)
        self.loader = loader
    }

    func image(at url: URL?, maximumPixelSize: Int = 480) async -> CGImage? {
        guard let url else { return nil }
        let key = ThemePreviewRequestKey(url: url, maximumPixelSize: maximumPixelSize)
        if let cached = cachedResult(for: key) {
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

        let staleKeys = cache.keys.filter {
            $0.url == url && $0.maximumPixelSize == maximumPixelSize
        }
        for staleKey in staleKeys {
            removeCachedResult(for: staleKey)
        }
        let staleInFlightKeys = inFlight.keys.filter {
            $0.url == url && $0.maximumPixelSize == maximumPixelSize
        }
        for staleKey in staleInFlightKeys {
            inFlight.removeValue(forKey: staleKey)?.task.cancel()
        }

        let loader = self.loader
        let token = UUID()
        let task = Task.detached(priority: .userInitiated) {
            loader(key)
        }
        inFlight[key] = InFlight(token: token, task: task)
        let loadedImage = await task.value
        guard inFlight[key]?.token == token else { return loadedImage }
        inFlight[key] = nil
        guard let image = loadedImage else {
            insert(.missing, for: key)
            return nil
        }
        insert(.image(image), for: key)
        return image
    }

    func invalidate(url: URL) {
        let matchingKeys = cache.keys.filter { $0.url == url }
        for key in matchingKeys {
            removeCachedResult(for: key)
        }
        let matchingInFlightKeys = inFlight.keys.filter { $0.url == url }
        for key in matchingInFlightKeys {
            inFlight.removeValue(forKey: key)?.task.cancel()
        }
    }

    private func cachedResult(for key: ThemePreviewRequestKey) -> CachedResult? {
        guard let result = cache[key] else { return nil }
        markRecentlyUsed(key)
        return result
    }

    private func insert(_ result: CachedResult, for key: ThemePreviewRequestKey) {
        guard maximumCacheEntries > 0, result.cost <= maximumCacheCost else { return }
        removeCachedResult(for: key)
        cache[key] = result
        cacheCost += result.cost
        markRecentlyUsed(key)

        while cacheCost > maximumCacheCost || cache.count > maximumCacheEntries {
            guard let oldestKey = cacheRecency.first else { break }
            removeCachedResult(for: oldestKey)
        }
    }

    private func markRecentlyUsed(_ key: ThemePreviewRequestKey) {
        cacheRecency.removeAll { $0 == key }
        cacheRecency.append(key)
    }

    private func removeCachedResult(for key: ThemePreviewRequestKey) {
        if let result = cache.removeValue(forKey: key) {
            cacheCost -= result.cost
        }
        cacheRecency.removeAll { $0 == key }
    }
}

enum ThemeGalleryLayout {
    static let minimumCardWidth = 168.0
    static let spacing = 12.0
    static let maximumColumns = 3
    static let inspectorWidth = 360.0
    static let inspectorPreviewHeight = 216.0
    static let cardRadius = HabitatDesignMetrics.cardRadius
    static let inspectorBreakpoint = 760.0

    static func columnCount(availableWidth: Double) -> Int {
        let fitting = Int((max(0, availableWidth) + spacing) / (minimumCardWidth + spacing))
        return min(maximumColumns, max(2, fitting))
    }

    static func cardWidth(availableWidth: Double) -> Double {
        let count = Double(columnCount(availableWidth: availableWidth))
        return (availableWidth - spacing * (count - 1)) / count
    }

    static func columns(availableWidth: Double) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: minimumCardWidth), spacing: spacing),
            count: columnCount(availableWidth: availableWidth)
        )
    }

    static func showsInlineInspector(availableWidth: Double) -> Bool {
        availableWidth >= inspectorBreakpoint
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
        GeometryReader { pageProxy in
            SettingsPage(
                "Themes",
                subtitle: "Browse local themes and explicitly apply a compatible choice",
                scrollBehavior: .pageOwned
            ) {
                VStack(spacing: 0) {
                    toolbar(
                        showsInspectorAction: !ThemeGalleryLayout.showsInlineInspector(
                            availableWidth: pageProxy.size.width
                        )
                    )
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
                    if ThemeGalleryLayout.showsInlineInspector(
                        availableWidth: proxy.size.width
                    ) {
                        HStack(spacing: 0) {
                            gallery
                            Divider()
                            themeInspector
                                .frame(width: ThemeGalleryLayout.inspectorWidth)
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
                ? L10n.text("Switch Codex to the selected theme?")
                : L10n.text("Restart Codex with the selected theme?"),
            isPresented: $confirmsCodexApply
        ) {
            Button(L10n.text("Cancel"), role: .cancel) {
                libraryState.clearPendingApply()
            }
            Button(bridge.state == .active ? L10n.text("Switch Theme") : L10n.text("Restart and Apply")) {
                applyPendingTheme()
            }
            .disabled(!bridge.canApply)
        } message: {
            Text(bridge.state == .active
                ? L10n.text("The current bridge theme will be replaced without restarting Codex.")
                : L10n.text("Codex will close and reopen on a local debugging port. Unsaved composer text may be lost. Restore closes the port and returns the official appearance."))
        }
        .confirmationDialog(
            L10n.text("Remove this Habitat pack?"),
            isPresented: Binding(
                get: { packageIDToRemove != nil },
                set: { if !$0 { packageIDToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.text("Remove Pack"), role: .destructive) {
                guard let packageIDToRemove else { return }
                self.packageIDToRemove = nil
                Task { await model.uninstallResourcePackage(id: packageIDToRemove) }
            }
            Button(L10n.text("Cancel"), role: .cancel) { packageIDToRemove = nil }
        } message: {
            Text(L10n.text("Pets and themes supplied by this pack will be removed from Habitat. Codex files are not changed."))
        }
        }
    }

    private func toolbar(showsInspectorAction: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchField.frame(minWidth: 170, idealWidth: 220, maxWidth: 280)
                scopePicker
                categoryMenu
                Spacer(minLength: 0)
                toolbarActions
                if showsInspectorAction {
                    compactInspectorButton(showsTitle: false)
                }
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
                    if showsInspectorAction {
                        compactInspectorButton(showsTitle: true)
                    }
                }
            }
        }
    }

    private func compactInspectorButton(showsTitle: Bool) -> some View {
        Button(action: { showsCompactInspector = true }) {
            if showsTitle {
                Label(L10n.text("Theme details"), systemImage: "sidebar.right")
            } else {
                Image(systemName: "sidebar.right")
                    .frame(width: 24, height: 24)
            }
        }
        .controlSize(.small)
        .help(L10n.text("Theme details"))
        .accessibilityLabel(L10n.text("Theme details"))
        .accessibilityIdentifier("themes.compact-inspector")
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
        Picker(L10n.text("Theme collection"), selection: $libraryState.scope) {
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
        GeometryReader { proxy in
            let contentWidth = max(0, proxy.size.width - 32)
            ScrollView {
                if filteredThemes.isEmpty {
                    emptyGallery
                        .padding(16)
                } else {
                    LazyVGrid(
                        columns: ThemeGalleryLayout.columns(availableWidth: contentWidth),
                        alignment: .leading,
                        spacing: ThemeGalleryLayout.spacing
                    ) {
                        ForEach(filteredThemes) { theme in
                            ThemeChoiceCard(
                                theme: theme,
                                isPreviewed: libraryState.previewedThemeID == theme.id,
                                isActiveInHabitat: model.settings.selectedThemeID == theme.id,
                                isActiveInCodex: bridge.state == .active && bridge.activeThemeID == theme.id,
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
        }
        .accessibilityIdentifier("themes.gallery")
    }

    private var themeInspector: some View {
        VStack(spacing: 0) {
            inspectorHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            Divider()
            ScrollView {
                inspectorContent
                    .padding(16)
            }
            .scrollIndicators(.automatic)
            Divider()
            inspectorActions
                .padding(12)
                .background { HabitatSurface(role: .toolbar) }
        }
        .accessibilityIdentifier("themes.inspector")
    }

    private var inspectorHeader: some View {
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
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help(L10n.text(isSelectedThemeFavorite ? "Remove from Favorites" : "Add to Favorites"))
            .accessibilityLabel(L10n.text(isSelectedThemeFavorite ? "Remove from Favorites" : "Add to Favorites"))
            if model.isThemeStudioEditableTheme(selectedTheme.id) {
                Button(action: { openThemeStudio(editingThemeID: selectedTheme.id) }) {
                    Image(systemName: "pencil")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(L10n.text("Edit theme"))
                .accessibilityLabel(L10n.text("Edit theme"))
            }
        }
    }

    private var inspectorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(L10n.text("Preview route"), selection: $libraryState.previewRoute) {
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
                height: ThemeGalleryLayout.inspectorPreviewHeight,
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

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12, alignment: .topLeading),
                    GridItem(.flexible(), spacing: 12, alignment: .topLeading),
                ],
                alignment: .leading,
                spacing: 14
            ) {
                inspectorStatusCell(
                    "Theme family",
                    value: selectedTheme.styleFamily.libraryTitle,
                    symbol: "square.3.layers.3d"
                )
                inspectorStatusCell(
                    "Codex compatibility",
                    value: selectedThemeSupportsBridge ? "Supported" : "Habitat only",
                    symbol: selectedThemeSupportsBridge ? "checkmark.shield" : "macwindow"
                )
            }

            inspectorBridgeStatus

            if bridge.canRestore {
                inspectorStatusCell(
                    "Restore",
                    value: "Restore available",
                    symbol: "arrow.uturn.backward"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isSelectedThemeActive || isSelectedThemeActiveInHabitat {
                HStack(spacing: 12) {
                    if isSelectedThemeActive {
                        Label(L10n.text("Active in Codex"), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("themes.inspector.active")
                    }
                    if isSelectedThemeActiveInHabitat {
                        Label(L10n.text("Active in Habitat"), systemImage: "macwindow.badge.checkmark")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("themes.inspector.habitat-active")
                    }
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    private var inspectorActions: some View {
        VStack(spacing: 8) {
            Button(action: requestInspectorApply) {
                Label(
                    L10n.text(isSelectedThemeActive ? "Active in Codex" : "Apply to Codex"),
                    systemImage: "paintbrush"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canApplySelectedTheme)
            .accessibilityIdentifier("themes.apply-to-codex")

            Button(action: useSelectedThemeInHabitat) {
                Label(
                    L10n.text(isSelectedThemeActiveInHabitat ? "Active in Habitat" : "Use in Habitat"),
                    systemImage: "macwindow"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isSelectedThemeActiveInHabitat)
            .accessibilityIdentifier("themes.use-in-habitat")
        }
    }

    private var inspectorBridgeStatus: some View {
        inspectorStatusCell(
            "Bridge status",
            value: bridge.statusText,
            symbol: bridge.state == .failed
                ? "exclamationmark.triangle"
                : "point.3.connected.trianglepath.dotted",
            valueLineLimit: 2
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inspectorStatusCell(
        _ title: String,
        value: String,
        symbol: String,
        valueLineLimit: Int = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(L10n.text(title), systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(L10n.text(value))
                .font(.caption.weight(.medium))
                .lineLimit(valueLineLimit)
                .fixedSize(horizontal: false, vertical: true)
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

    private var isSelectedThemeActiveInHabitat: Bool {
        model.settings.selectedThemeID == selectedTheme.id
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

    private func useSelectedThemeInHabitat() {
        guard !isSelectedThemeActiveInHabitat else { return }
        model.selectTheme(selectedTheme.id)
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
                model.setThemeBridgeActive(true, themeID: themeID)
            }
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

    private var previewLoadIdentity: ThemePreviewLoadIdentity {
        ThemePreviewLoadIdentity(url: imageURL, reloadGeneration: reloadGeneration)
    }
}

enum ThemeChoiceCardVisualState {
    static func showsFavoriteControl(
        isFavorite: Bool,
        isPreviewed: Bool,
        isHovered: Bool
    ) -> Bool {
        isFavorite || isPreviewed || isHovered
    }
}

struct ThemeChoiceCard: View {
    let theme: HabitatThemeDescriptor
    let isPreviewed: Bool
    let isActiveInHabitat: Bool
    let isActiveInCodex: Bool
    let isFavorite: Bool
    let action: () -> Void
    let favoriteAction: (() -> Void)?
    @State private var previewRetryAvailable = false
    @State private var previewReloadGeneration = 0
    @State private var isHovered = false

    init(
        theme: HabitatThemeDescriptor,
        isPreviewed: Bool,
        isActiveInHabitat: Bool = false,
        isActiveInCodex: Bool = false,
        isFavorite: Bool = false,
        action: @escaping () -> Void,
        favoriteAction: (() -> Void)? = nil
    ) {
        self.theme = theme
        self.isPreviewed = isPreviewed
        self.isActiveInHabitat = isActiveInHabitat
        self.isActiveInCodex = isActiveInCodex
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
                            HStack(spacing: 5) {
                                Text(L10n.text(theme.styleFamily.libraryTitle))
                                    .lineLimit(1)
                                if isActiveInHabitat {
                                    Image(systemName: "macwindow")
                                        .help(L10n.text("Active in Habitat"))
                                }
                                if isActiveInCodex {
                                    Image(systemName: "paintbrush.fill")
                                        .help(L10n.text("Active in Codex"))
                                }
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 46)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: ThemeGalleryLayout.cardRadius))
                .overlay {
                    if !isPreviewed {
                        RoundedRectangle(cornerRadius: ThemeGalleryLayout.cardRadius)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                    }
                }
            }
            .buttonStyle(HabitatPressButtonStyle(radius: ThemeGalleryLayout.cardRadius))
            .habitatHoverStyle(radius: ThemeGalleryLayout.cardRadius)
            .habitatSelectedStyle(isPreviewed, radius: ThemeGalleryLayout.cardRadius)
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
            if let favoriteAction,
               ThemeChoiceCardVisualState.showsFavoriteControl(
                   isFavorite: isFavorite,
                   isPreviewed: isPreviewed,
                   isHovered: isHovered
               ) {
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
        .onHover { isHovered = $0 }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
    }

    private var accessibilityValue: String {
        [
            L10n.text(isPreviewed ? "Previewed" : "Not previewed"),
            L10n.text(isActiveInHabitat ? "Active in Habitat" : "Inactive in Habitat"),
            L10n.text(isActiveInCodex ? "Active in Codex" : "Inactive in Codex"),
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

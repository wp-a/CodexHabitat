import AppKit
import HabitatCore
import ResourceKit
import SwiftUI
import UniformTypeIdentifiers

enum ThemeStudioLayoutMetrics {
    static let inspectorMinimumWidth = 352.0
    static let inspectorIdealWidth = 368.0
    static let inspectorMaximumWidth = 388.0
    static let toolbarHeight = 48.0
}

enum ThemeStudioInspectorSection: CaseIterable, Hashable, Sendable {
    case metadata
    case artwork
    case palette
    case scene
    case material
    case petPairing
    case package
}

enum ThemeStudioInspectorGroup: CaseIterable, Hashable, Sendable {
    case basic
    case appearance
    case advanced

    static let defaultExpanded: Set<Self> = [.basic]

    var sections: [ThemeStudioInspectorSection] {
        switch self {
        case .basic:
            [.metadata, .artwork]
        case .appearance:
            [.palette, .scene, .material]
        case .advanced:
            [.petPairing, .package]
        }
    }
}

struct ThemeStudioCanvasPresentation: Equatable, Sendable {
    let rendersHostShell: Bool
    let showsArtworkPrompt: Bool
    let allowsFocalEditing: Bool

    init(draft: ThemeStudioDraft) {
        rendersHostShell = true
        showsArtworkPrompt = draft.sourceImageURL == nil
        allowsFocalEditing = draft.sourceImageURL != nil && draft.palette != nil
    }
}

struct ThemeStudioView: View {
    @ObservedObject var model: ThemeStudioModel
    let onSaved: (String, String?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusField?
    @State private var expandedGroups = ThemeStudioInspectorGroup.defaultExpanded
    @State private var pendingExportURL: URL?
    @State private var showsRightsConfirmation = false
    @State private var rightsAccepted = false
    @State private var previewRoute = ThemeTreatmentPreviewRoute.home
    @State private var showsSafeArea = false
    @State private var isDraggingFocus = false
    @State private var isDropTargeted = false
    @State private var pendingReplacementThemeID: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HSplitView {
                canvasPane
                    .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
                inspector
                    .frame(
                        minWidth: ThemeStudioLayoutMetrics.inspectorMinimumWidth,
                        idealWidth: ThemeStudioLayoutMetrics.inspectorIdealWidth,
                        maxWidth: ThemeStudioLayoutMetrics.inspectorMaximumWidth,
                        maxHeight: .infinity
                    )
            }
            Divider()
            footer
        }
        .frame(minWidth: 940, idealWidth: 1_040, minHeight: 620, idealHeight: 700)
        .background(HabitatSurface(role: .content))
        .interactiveDismissDisabled(model.isDirty || model.state == .saving || model.isSelectingImage)
        .confirmationDialog(
            L10n.text("Discard this theme draft?"),
            isPresented: $model.showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("Discard Draft"), role: .destructive) {
                model.discardDraft()
                dismiss()
            }
            .disabled(model.state == .saving)
            Button(L10n.text("Keep Editing"), role: .cancel) {}
        } message: {
            Text(L10n.text("Unsaved theme changes will be lost."))
        }
        .confirmationDialog(
            L10n.text("Confirm image rights"),
            isPresented: $showsRightsConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("Export Theme")) {
                rightsAccepted = true
                exportPendingTheme()
            }
            Button(L10n.text("Cancel"), role: .cancel) { pendingExportURL = nil }
        } message: {
            Text(L10n.text("Export does not grant image rights. You confirm you may use and share this image."))
        }
        .confirmationDialog(
            L10n.text("Replace existing theme?"),
            isPresented: Binding(
                get: { pendingReplacementThemeID != nil },
                set: { if !$0 { pendingReplacementThemeID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.text("Replace Theme"), role: .destructive, action: replaceExistingTheme)
            Button(L10n.text("Cancel"), role: .cancel) {
                pendingReplacementThemeID = nil
                model.cancelReplacement()
            }
        } message: {
            Text(L10n.text("A local theme with this name already exists. Replace it with this draft?"))
        }
        .onChange(of: model.state) { _, state in
            guard case let .replacementRequired(id) = state else { return }
            pendingReplacementThemeID = id
        }
        .onDisappear {
            model.endContinuousEdit()
        }
    }

    private var toolbar: some View {
        HStack(spacing: HabitatDesignMetrics.spaceM) {
            Image(systemName: "paintbrush.pointed.fill")
                .foregroundStyle(accentColor)
            Text(L10n.text("Theme Studio"))
                .font(.headline)

            Divider()
                .frame(height: 18)

            Picker(L10n.text("Preview route"), selection: $previewRoute) {
                Text(L10n.text("Home")).tag(ThemeTreatmentPreviewRoute.home)
                Text(L10n.text("Task")).tag(ThemeTreatmentPreviewRoute.task)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 164)

            Toggle(isOn: $showsSafeArea) {
                Label(L10n.text("Safe regions"), systemImage: "viewfinder")
            }
            .toggleStyle(.button)
            .help(L10n.text("Safe regions"))

            Button(action: copyCodexThemeString) {
                Label(L10n.text("Copy Share String"), systemImage: "doc.on.doc")
            }
            .help(L10n.text("Copy Share String"))

            Spacer(minLength: HabitatDesignMetrics.spaceM)

            Button(action: model.undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo || model.isSelectingImage || model.state == .saving)
            .help(L10n.text("Undo"))
            .accessibilityLabel(L10n.text("Undo"))

            Button(action: model.redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!model.canRedo || model.isSelectingImage || model.state == .saving)
            .help(L10n.text("Redo"))
            .accessibilityLabel(L10n.text("Redo"))
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, HabitatDesignMetrics.spaceL)
        .frame(height: ThemeStudioLayoutMetrics.toolbarHeight)
        .background(HabitatSurface(role: .toolbar))
    }

    private var canvasPane: some View {
        previewCanvas
            .padding(HabitatDesignMetrics.spaceXL)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HabitatSurface(role: .content))
    }

    private var previewCanvas: some View {
        GeometryReader { geometry in
            let canvasSize = aspectFit16By10(in: geometry.size)
            let presentation = ThemeStudioCanvasPresentation(draft: model.draft)
            ZStack(alignment: .topTrailing) {
                if presentation.rendersHostShell {
                    artworkEditor(size: canvasSize)
                }
                if presentation.showsArtworkPrompt || isDropTargeted {
                    dropArtworkBanner
                        .frame(width: canvasSize.width, height: canvasSize.height)
                }
                if presentation.showsArtworkPrompt {
                    emptyArtwork
                        .padding(12)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDroppedFiles)
        .accessibilityIdentifier("theme-studio.canvas")
    }

    private func artworkEditor(size: CGSize) -> some View {
        let canvasRect = CGRect(origin: .zero, size: size)
        let artworkRect = ThemeFocalPointMapper.artworkRect(
            in: canvasRect,
            route: previewRoute,
            taskMode: model.taskMode
        )
        let focus = currentFocus
        let markerPoint = CGPoint(
            x: canvasRect.minX + focus.x * canvasRect.width,
            y: canvasRect.minY + focus.y * canvasRect.height
        )

        return ZStack(alignment: .topLeading) {
            ThemeTreatmentPreview(
                model: previewModel,
                imageURL: model.sourceImageURL,
                symbol: "paintpalette.fill",
                route: previewRoute,
                height: size.height,
                showsFallbackSymbol: false,
                showsFrame: false
            )
            .frame(width: size.width, height: size.height)

            if showsSafeArea {
                safeAreaOverlay(in: canvasRect)
            }

            Color.clear
                .contentShape(Rectangle())
                .frame(width: artworkRect.width, height: artworkRect.height)
                .offset(x: artworkRect.minX, y: artworkRect.minY)
                .gesture(focalDragGesture(in: canvasRect), including: canEditArtwork ? .all : .none)
                .accessibilityHidden(true)

            if canEditArtwork, markerPoint.y <= artworkRect.maxY {
                focalMarker(in: canvasRect)
                    .position(
                        x: canvasRect.minX + focus.x * canvasRect.width,
                        y: canvasRect.minY + focus.y * canvasRect.height
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: "theme-studio.artwork")
        .clipShape(RoundedRectangle(cornerRadius: HabitatDesignMetrics.previewRadius))
        .overlay {
            RoundedRectangle(cornerRadius: HabitatDesignMetrics.previewRadius)
                .stroke(.primary.opacity(0.14), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func focalMarker(in artworkRect: CGRect) -> some View {
        Button(action: {}) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.5))
                    .frame(width: 24, height: 24)
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(focalDragGesture(in: artworkRect))
        .focusable()
        .onMoveCommand(perform: moveFocalPoint)
        .accessibilityLabel(L10n.text("Artwork focal point"))
        .accessibilityValue(focalPointAccessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustFocalPoint(dx: 0.01, dy: 0)
            case .decrement:
                adjustFocalPoint(dx: -0.01, dy: 0)
            @unknown default:
                break
            }
        }
        .help(L10n.text("Artwork focal point"))
    }

    private func safeAreaOverlay(in rect: CGRect) -> some View {
        let safeWidth = rect.width * 0.36
        let x: Double = switch model.safeSide {
        case .leading: rect.minX
        case .trailing: rect.maxX - safeWidth
        case .center: rect.midX - safeWidth / 2
        case .none: rect.midX - safeWidth / 2
        }
        return ZStack {
            Rectangle()
                .fill(accentColor.opacity(model.safeSide == .none ? 0.04 : 0.10))
            Rectangle()
                .stroke(accentColor.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
        .frame(width: safeWidth, height: rect.height)
        .offset(x: x, y: rect.minY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var inspector: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ThemeStudioDisclosureSection(
                        title: "Basic",
                        isExpanded: groupBinding(.basic)
                    ) {
                        ThemeStudioInspectorSubsection(title: "Metadata") {
                            metadataControls
                        }
                        ThemeStudioInspectorSubsection(title: "Artwork") {
                            artworkControls
                        }
                    }
                    .id(ThemeStudioInspectorGroup.basic)
                    ThemeStudioDisclosureSection(
                        title: "Appearance",
                        isExpanded: groupBinding(.appearance)
                    ) {
                        ThemeStudioInspectorSubsection(title: "Palette") {
                            paletteControls
                        }
                        ThemeStudioInspectorSubsection(title: "Scene") {
                            sceneControls
                        }
                        ThemeStudioInspectorSubsection(title: "Material") {
                            materialControls
                        }
                    }
                    .id(ThemeStudioInspectorGroup.appearance)
                    ThemeStudioDisclosureSection(
                        title: "Advanced",
                        isExpanded: groupBinding(.advanced)
                    ) {
                        ThemeStudioInspectorSubsection(title: "Pet Pairing") {
                            pairingControls
                        }
                        ThemeStudioInspectorSubsection(title: "Package") {
                            packageControls
                        }
                    }
                    .id(ThemeStudioInspectorGroup.advanced)
                }
                .padding(.horizontal, HabitatDesignMetrics.spaceM)
                .padding(.vertical, HabitatDesignMetrics.spaceS)
                .disabled(model.isSelectingImage || model.state == .saving)
            }
            .onChange(of: model.state) { _, state in
                guard case .validationFailure = state else { return }
                focusFirstValidationError(using: proxy)
            }
        }
        .background(HabitatSurface(role: .inspector))
    }

    private var metadataControls: some View {
        VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceM) {
            VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceXS) {
                Text(L10n.text("Theme name"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(L10n.text("Theme name"), text: Binding(
                    get: { model.name },
                    set: { model.name = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
                .accessibilityIdentifier("theme-studio.name")
            }
            if let message = model.nameValidationMessage {
                validation(message)
            }

            VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceXS) {
                Text(L10n.text("Author (optional)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(L10n.text("Author (optional)"), text: Binding(
                    get: { model.author },
                    set: { model.author = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .author)
                .accessibilityIdentifier("theme-studio.author")
            }
            if let message = model.authorValidationMessage {
                validation(message)
            }

            Picker(L10n.text("Category"), selection: Binding(
                get: { model.category },
                set: { model.setCategory($0) }
            )) {
                ForEach(HabitatThemeCategory.allCases, id: \.self) { category in
                    Text(L10n.text(category.localizationKey)).tag(category)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var artworkControls: some View {
        VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceM) {
            Button(action: chooseImage) {
                Label(L10n.text("Choose Image"), systemImage: "photo")
            }
            .focused($focusedField, equals: .image)
            .accessibilityIdentifier("theme-studio.choose-image")
            .disabled(model.isSelectingImage || model.state == .saving)

            if let sourceImageURL = model.sourceImageURL {
                Text(sourceImageURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(sourceImageURL.lastPathComponent)
            }
            if let message = model.imageValidationMessage {
                validation(message)
            }

            valueSlider(
                "Focal point X",
                value: currentFocus.x,
                range: 0...1,
                step: 0.01,
                valueText: ThemeStudioUnitValueFormatter.string(for: currentFocus.x),
                setter: { setCurrentFocus(x: $0, y: currentFocus.y) }
            )
            valueSlider(
                "Focal point Y",
                value: currentFocus.y,
                range: 0...1,
                step: 0.01,
                valueText: ThemeStudioUnitValueFormatter.string(for: currentFocus.y),
                setter: { setCurrentFocus(x: currentFocus.x, y: $0) }
            )
            valueSlider(
                previewRoute == .home ? "Home artwork scale" : "Task artwork scale",
                value: previewRoute == .home ? model.homeArtScale : model.taskArtScale,
                range: 1...1.35,
                step: 0.01,
                format: "%.0f%%",
                setter: { value in
                    if previewRoute == .home {
                        model.setHomeArtScale(value)
                    } else {
                        model.setTaskArtScale(value)
                    }
                },
                displayScale: 100
            )
        }
    }

    @ViewBuilder
    private var paletteControls: some View {
        if model.palette == nil {
            Text(L10n.text("Choose an image to generate a starting palette."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 128), spacing: HabitatDesignMetrics.spaceS)],
                alignment: .leading,
                spacing: HabitatDesignMetrics.spaceS
            ) {
                ForEach(ThemePaletteRole.allCases, id: \.self) { role in
                    ColorPicker(role.title, selection: colorBinding(role), supportsOpacity: false)
                }
            }
        }
    }

    private var sceneControls: some View {
        VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceM) {
            VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceXS) {
                Text(L10n.text("Mood Presets"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 6
                ) {
                    ForEach(ThemeStudioMoodPreset.allCases) { preset in
                        Button {
                            model.applyMoodPreset(preset)
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(habitatHex: preset.accentHex))
                                    .frame(width: 8, height: 8)
                                Text(L10n.text(preset.titleKey))
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                .quaternary.opacity(0.45),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Picker(L10n.text("Style"), selection: Binding(
                get: { model.styleFamily },
                set: { model.setStyleFamily($0) }
            )) {
                ForEach(HabitatThemeStyleFamily.allCases, id: \.self) { family in
                    Text(family.studioTitle).tag(family)
                }
            }
            .pickerStyle(.menu)

            Picker(L10n.text("Safe side"), selection: Binding(
                get: { model.safeSide },
                set: { model.setSafeSide($0) }
            )) {
                Text(L10n.text("Leading")).tag(HabitatThemeSafeSide.leading)
                Text(L10n.text("Trailing")).tag(HabitatThemeSafeSide.trailing)
                Text(L10n.text("Center")).tag(HabitatThemeSafeSide.center)
                Text(L10n.text("None")).tag(HabitatThemeSafeSide.none)
            }
            .pickerStyle(.menu)

            if previewRoute == .home {
                Picker(L10n.text("Home treatment"), selection: Binding(
                    get: { model.homeMode },
                    set: { model.setHomeMode($0) }
                )) {
                    Text(L10n.text("Immersive")).tag(HabitatThemeHomeMode.immersive)
                    Text(L10n.text("Framed")).tag(HabitatThemeHomeMode.framed)
                    Text(L10n.text("Quiet")).tag(HabitatThemeHomeMode.quiet)
                }
                .pickerStyle(.segmented)
                valueSlider(
                    "Home strength",
                    value: model.homeStrength,
                    range: 0.10...0.85,
                    step: 0.01,
                    format: "%.0f%%",
                    setter: { model.setHomeStrength($0) },
                    displayScale: 100
                )
                valueSlider(
                    "Home content opacity",
                    value: model.homeContentOpacity,
                    range: 0.40...0.78,
                    step: 0.01,
                    format: "%.0f%%",
                    setter: { model.setHomeContentOpacity($0) },
                    displayScale: 100
                )
            } else {
                Picker(L10n.text("Task treatment"), selection: Binding(
                    get: { model.taskMode },
                    set: { model.setTaskMode($0) }
                )) {
                    Text(L10n.text("Ambient")).tag(HabitatThemeTaskMode.ambient)
                    Text(L10n.text("Banner")).tag(HabitatThemeTaskMode.banner)
                    Text(L10n.text("Off")).tag(HabitatThemeTaskMode.off)
                }
                .pickerStyle(.segmented)
                valueSlider(
                    "Task strength",
                    value: model.taskStrength,
                    range: 0.10...0.85,
                    step: 0.01,
                    format: "%.0f%%",
                    setter: { model.setTaskStrength($0) },
                    displayScale: 100
                )
                valueSlider(
                    "Task content opacity",
                    value: model.taskContentOpacity,
                    range: 0.60...0.84,
                    step: 0.01,
                    format: "%.0f%%",
                    setter: { model.setTaskContentOpacity($0) },
                    displayScale: 100
                )
            }
        }
    }

    private var materialControls: some View {
        VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceM) {
            Picker(L10n.text("Density"), selection: Binding(
                get: { model.density },
                set: { model.setDensity($0) }
            )) {
                Text(L10n.text("Compact")).tag(HabitatThemeDensity.compact)
                Text(L10n.text("Comfortable")).tag(HabitatThemeDensity.comfortable)
            }
            .pickerStyle(.segmented)

            Picker(L10n.text("Chrome material"), selection: Binding(
                get: { model.chromeMaterial },
                set: { model.setChromeMaterial($0) }
            )) {
                Text(L10n.text("Solid")).tag(HabitatThemeChromeMaterial.solid)
                Text(L10n.text("Tinted")).tag(HabitatThemeChromeMaterial.tinted)
                Text(L10n.text("Glass")).tag(HabitatThemeChromeMaterial.glass)
            }
            .pickerStyle(.segmented)

            valueSlider(
                "Blur",
                value: model.blurRadius,
                range: 0...24,
                step: 1,
                format: "%.0f pt",
                setter: { model.setBlurRadius($0) }
            )
            valueSlider(
                previewRoute == .home ? "Sidebar opacity" : "Task sidebar opacity",
                value: previewRoute == .home ? model.sidebarOpacity : model.taskSidebarOpacity,
                range: sidebarOpacityRange,
                step: 0.01,
                format: "%.0f%%",
                setter: { value in
                    if previewRoute == .home {
                        model.setSidebarOpacity(value)
                    } else {
                        model.setTaskSidebarOpacity(value)
                    }
                },
                displayScale: 100
            )
            valueSlider(
                previewRoute == .home ? "Header opacity" : "Task header opacity",
                value: previewRoute == .home ? model.headerOpacity : model.taskHeaderOpacity,
                range: headerOpacityRange,
                step: 0.01,
                format: "%.0f%%",
                setter: { value in
                    if previewRoute == .home {
                        model.setHeaderOpacity(value)
                    } else {
                        model.setTaskHeaderOpacity(value)
                    }
                },
                displayScale: 100
            )
            if previewRoute == .task {
                valueSlider(
                    "Composer opacity",
                    value: model.composerOpacity,
                    range: 0.40...1,
                    step: 0.01,
                    format: "%.0f%%",
                    setter: { model.setComposerOpacity($0) },
                    displayScale: 100
                )
            }
            valueSlider(
                "Vignette strength",
                value: model.vignetteStrength,
                range: 0...0.70,
                step: 0.01,
                format: "%.0f%%",
                setter: { model.setVignetteStrength($0) },
                displayScale: 100
            )
        }
    }

    @ViewBuilder
    private var pairingControls: some View {
        if model.availablePets.isEmpty {
            Text(L10n.text("None"))
                .foregroundStyle(.secondary)
        } else {
            Picker(L10n.text("Pet"), selection: Binding(
                get: { model.pairedPetID },
                set: { model.setPairedPetID($0) }
            )) {
                Text(L10n.text("None")).tag(String?.none)
                ForEach(model.availablePets) { pet in
                    Text(pet.name).tag(String?.some(pet.id))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var packageControls: some View {
        VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceS) {
            LabeledContent(L10n.text("Format"), value: L10n.text("Habitat Pack"))
            LabeledContent(L10n.text("Theme ID"), value: ThemePackageBuilder.safeID(for: model.name))
                .lineLimit(1)
            Label(L10n.text("Local image"), systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: HabitatDesignMetrics.spaceS) {
            stateLabel
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(L10n.text("Cancel"), action: close)
                .keyboardShortcut(.cancelAction)
                .disabled(model.state == .saving)
                .frame(minHeight: HabitatDesignMetrics.standardControlHeight)
            Button(action: beginExport) {
                Label(L10n.text("Export"), systemImage: "square.and.arrow.up")
            }
            .disabled(!model.canPersistDraft || model.isSelectingImage || model.state == .saving)
            .help(model.persistenceRequirementMessage ?? L10n.text("Export Theme"))
            .accessibilityHint(model.persistenceRequirementMessage ?? L10n.text("Export Theme"))
            .frame(minHeight: HabitatDesignMetrics.standardControlHeight)
            Button(action: saveLocally) {
                Label(L10n.text("Save Locally"), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canPersistDraft || model.isSelectingImage || model.state == .saving)
            .help(model.persistenceRequirementMessage ?? L10n.text("Save Locally"))
            .accessibilityHint(model.persistenceRequirementMessage ?? L10n.text("Save Locally"))
            .frame(minHeight: HabitatDesignMetrics.prominentControlHeight)
            .accessibilityIdentifier("theme-studio.save")
        }
        .padding(.horizontal, HabitatDesignMetrics.spaceL)
        .frame(minHeight: 56, idealHeight: 58, maxHeight: 60)
        .background(HabitatSurface(role: .toolbar))
    }

    @ViewBuilder
    private var stateLabel: some View {
        if model.isSelectingImage {
            HStack(spacing: HabitatDesignMetrics.spaceS) {
                ProgressView().controlSize(.small)
                Text(L10n.text("Analyzing image"))
            }
        } else {
            switch model.state {
            case .editing:
                if let message = model.persistenceRequirementMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else if model.isDirty {
                    Label(L10n.text("Unsaved changes"), systemImage: "circle.fill")
                        .foregroundStyle(.secondary)
                }
            case .saving:
                HStack(spacing: HabitatDesignMetrics.spaceS) {
                    ProgressView().controlSize(.small)
                    Text(L10n.text("Saving"))
                }
            case .replacementRequired:
                Label(L10n.text("Replacement confirmation required"), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case let .validationFailure(message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .saved:
                Label(L10n.text("Saved"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private var emptyArtwork: some View {
        Button(action: chooseImage) {
            Image(systemName: "photo.badge.plus")
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(model.isSelectingImage || model.state == .saving)
        .help(L10n.text("Choose Image"))
        .accessibilityLabel(L10n.text("Choose Image"))
        .accessibilityIdentifier("theme-studio.empty-artwork")
    }

    private var previewModel: ThemeTreatmentPreviewModel {
        ThemeTreatmentPreviewModel(
            appearance: model.previewAppearance,
            surfaceHex: model.color(for: .surface) ?? "#101820",
            panelHex: model.color(for: .panel) ?? "#182633",
            panelAltHex: model.color(for: .panelAlt) ?? "#24384A",
            textHex: model.color(for: .text) ?? "#F4FAFF",
            accentHex: model.color(for: .accent) ?? "#16C6D9"
        )
    }

    private var accentColor: Color {
        Color(habitatHex: model.color(for: .accent) ?? "#1687E8")
    }

    private var currentFocus: HabitatThemeFocalPoint {
        previewRoute == .home ? model.homeArtFocus : model.taskArtFocus
    }

    private var canEditArtwork: Bool {
        model.sourceImageURL != nil
            && model.palette != nil
            && !model.isSelectingImage
            && model.state != .saving
    }

    private var sidebarOpacityRange: ClosedRange<Double> {
        previewRoute == .home ? 0.40...1 : 0.54...0.90
    }

    private var headerOpacityRange: ClosedRange<Double> {
        previewRoute == .home ? 0...1 : 0.54...0.90
    }

    private var focalPointAccessibilityValue: String {
        [currentFocus.x, currentFocus.y]
            .map(ThemeStudioUnitValueFormatter.string(for:))
            .joined(separator: ", ")
    }

    private func focalDragGesture(in artworkRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("theme-studio.artwork"))
            .onChanged { value in
                guard canEditArtwork else { return }
                if !isDraggingFocus {
                    isDraggingFocus = true
                    model.beginContinuousEdit()
                }
                let point = ThemeFocalPointMapper.unitPoint(at: value.location, in: artworkRect)
                setCurrentFocus(x: point.x, y: point.y)
            }
            .onEnded { _ in
                guard isDraggingFocus else { return }
                isDraggingFocus = false
                model.endContinuousEdit()
            }
    }

    private func setCurrentFocus(x: Double, y: Double) {
        if previewRoute == .home {
            model.setHomeArtFocus(x: x, y: y)
        } else {
            model.setTaskArtFocus(x: x, y: y)
        }
    }

    private func adjustFocalPoint(dx: Double, dy: Double) {
        setCurrentFocus(x: currentFocus.x + dx, y: currentFocus.y + dy)
    }

    private func moveFocalPoint(_ direction: MoveCommandDirection) {
        switch direction {
        case .left: adjustFocalPoint(dx: -0.01, dy: 0)
        case .right: adjustFocalPoint(dx: 0.01, dy: 0)
        case .up: adjustFocalPoint(dx: 0, dy: -0.01)
        case .down: adjustFocalPoint(dx: 0, dy: 0.01)
        @unknown default: break
        }
    }

    private func aspectFit16By10(in available: CGSize) -> CGSize {
        let ratio = 16.0 / 10.0
        let width = min(available.width, available.height * ratio)
        return CGSize(width: width, height: width / ratio)
    }

    private func valueSlider(
        _ title: String,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        format: String? = nil,
        valueText: String? = nil,
        setter: @MainActor @escaping @Sendable (Double) -> Void,
        displayScale: Double = 1
    ) -> some View {
        let displayValue = valueText
            ?? format.map { String(format: $0, value * displayScale) }
            ?? String(value * displayScale)
        return VStack(spacing: HabitatDesignMetrics.spaceXS) {
            HStack(spacing: HabitatDesignMetrics.spaceS) {
                Text(L10n.text(title))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                Text(displayValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(get: { value }, set: { setter($0) }),
                in: range,
                step: step,
                onEditingChanged: { isEditing in
                    if isEditing {
                        model.beginContinuousEdit()
                    } else {
                        model.endContinuousEdit()
                    }
                }
            )
            .accessibilityLabel(L10n.text(title))
            .accessibilityValue(displayValue)
        }
    }

    private func groupBinding(_ group: ThemeStudioInspectorGroup) -> Binding<Bool> {
        Binding(
            get: { expandedGroups.contains(group) },
            set: { isExpanded in
                if isExpanded {
                    expandedGroups.insert(group)
                } else {
                    expandedGroups.remove(group)
                }
            }
        )
    }

    private func colorBinding(_ role: ThemePaletteRole) -> Binding<Color> {
        Binding(
            get: { Color(habitatHex: model.color(for: role) ?? "#000000") },
            set: { model.setColor(role, hex: NSColor($0).habitatHexString) }
        )
    }

    private func validation(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func focusFirstValidationError(using proxy: ScrollViewProxy) {
        if model.nameValidationMessage != nil {
            focusedField = .name
        } else if model.authorValidationMessage != nil {
            focusedField = .author
        } else {
            focusedField = .image
        }
        let group = ThemeStudioInspectorGroup.basic
        expandedGroups.insert(group)
        if reduceMotion {
            proxy.scrollTo(group, anchor: .top)
        } else {
            withAnimation(.easeOut(duration: HabitatMotion.navigationDuration)) {
                proxy.scrollTo(group, anchor: .top)
            }
        }
    }

    private var dropArtworkBanner: some View {
        ZStack(alignment: isDropTargeted ? .center : .top) {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: HabitatDesignMetrics.previewRadius)
                    .fill(accentColor.opacity(0.20))
            }
            HStack(spacing: 8) {
                Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "photo.on.rectangle.angled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(L10n.text(isDropTargeted ? "Drop image to extract palette" : "Drop a PNG, JPEG, or WebP wallpaper here"))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, isDropTargeted ? 0 : 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isDropTargeted ? .center : .top)
        .allowsHitTesting(false)
    }

    private func chooseImage() {
        guard let url = ResourcePackPanels.chooseThemeImage() else { return }
        loadStudioImage(url)
    }

    private func loadStudioImage(_ url: URL) {
        Task {
            if (try? await model.selectImage(url)) != nil {
                expandedGroups.insert(.appearance)
            }
        }
    }

    private func handleDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        guard !model.isSelectingImage, model.state != .saving,
              let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) })
        else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let resolvedURL: URL?
            if let data = item as? Data {
                resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                resolvedURL = url
            } else {
                resolvedURL = nil
            }
            guard let resolvedURL, resolvedURL.isFileURL else { return }
            Task { @MainActor in
                loadStudioImage(resolvedURL)
            }
        }
        return true
    }

    private func saveLocally() {
        Task {
            await model.saveLocally()
            finishSavedTheme()
        }
    }

    private func replaceExistingTheme() {
        pendingReplacementThemeID = nil
        Task {
            await model.replaceExistingTheme()
            finishSavedTheme()
        }
    }

    private func finishSavedTheme() {
        guard case let .saved(id) = model.state else { return }
        onSaved(id, model.pairedPetID)
        dismiss()
    }

    private func beginExport() {
        guard model.validateDraftForPersistence() else { return }
        guard let url = ResourcePackPanels.chooseThemeExport(name: model.name) else { return }
        pendingExportURL = url
        if rightsAccepted {
            exportPendingTheme()
        } else {
            showsRightsConfirmation = true
        }
    }

    private func exportPendingTheme() {
        guard let pendingExportURL else { return }
        self.pendingExportURL = nil
        Task { await model.export(to: pendingExportURL) }
    }

    private func close() {
        if model.requestClose() {
            dismiss()
        }
    }

    private func copyCodexThemeString() {
        let descriptor = HabitatThemeDescriptor(
            id: ThemePackageBuilder.safeID(for: model.name.isEmpty ? "studio" : model.name),
            name: model.name.isEmpty ? "Studio Theme" : model.name,
            detail: model.author,
            symbol: "paintpalette.fill",
            surfaceHex: model.color(for: .surface) ?? "#101820",
            panelHex: model.color(for: .panel) ?? "#182633",
            panelAltHex: model.color(for: .panelAlt) ?? "#24384A",
            textHex: model.color(for: .text) ?? "#F4FAFF",
            mutedTextHex: model.color(for: .mutedText) ?? "#AAB8C4",
            accentHex: model.color(for: .accent) ?? "#16C6D9",
            secondaryHex: model.color(for: .secondary) ?? "#41D17D",
            highlightHex: model.color(for: .highlight) ?? "#85F4FF",
            attentionHex: model.color(for: .attention) ?? "#FFB547",
            errorHex: model.color(for: .error) ?? "#FF5C70",
            previewURL: nil
        )
        let variant = CodexThemeShareString.suggestedVariant(for: descriptor)
        let share = CodexThemeShareString.make(theme: descriptor, variant: variant)
        guard !share.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(share, forType: .string)
    }
}

private struct ThemeStudioDisclosureSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceM) {
                content
            }
            .padding(.top, HabitatDesignMetrics.spaceM)
            .padding(.bottom, HabitatDesignMetrics.spaceL)
        } label: {
            Text(L10n.text(title))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, HabitatDesignMetrics.spaceM)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct ThemeStudioInspectorSubsection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HabitatDesignMetrics.spaceS) {
            Text(L10n.text(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

private enum FocusField: Hashable {
    case name
    case author
    case image
}

private extension ThemePaletteRole {
    var title: String {
        switch self {
        case .surface: L10n.text("Surface")
        case .panel: L10n.text("Panel")
        case .panelAlt: L10n.text("Alternate panel")
        case .text: L10n.text("Text")
        case .mutedText: L10n.text("Muted text")
        case .accent: L10n.text("Accent")
        case .secondary: L10n.text("Secondary")
        case .highlight: L10n.text("Highlight")
        case .attention: L10n.text("Attention")
        case .error: L10n.text("Error")
        }
    }
}

private extension HabitatThemeStyleFamily {
    var studioTitle: String {
        switch self {
        case .arcade: L10n.text("Arcade")
        case .retroMessenger: L10n.text("Retro Messenger")
        case .greenChat: L10n.text("Green Chat")
        case .classicDesktop: L10n.text("Classic Desktop")
        case .gameCinematic: L10n.text("Game Cinematic")
        case .cozyWorld: L10n.text("Cozy World")
        case .animeEnergy: L10n.text("Anime Energy")
        case .fantasyAdventure: L10n.text("Fantasy Adventure")
        case .pixelWorld: L10n.text("Pixel World")
        }
    }
}

private extension NSColor {
    var habitatHexString: String {
        let color = usingColorSpace(.sRGB) ?? .black
        return String(
            format: "#%02X%02X%02X",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }
}

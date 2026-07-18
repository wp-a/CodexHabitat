import AppKit
import HabitatCore
import SwiftUI

struct ThemeStudioView: View {
    @ObservedObject var model: ThemeStudioModel
    let onSaved: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingExportURL: URL?
    @State private var showsRightsConfirmation = false
    @State private var rightsAccepted = false
    @State private var previewRoute = ThemeTreatmentPreviewRoute.home

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                Form {
                    identitySection
                    backgroundSection
                    paletteSection
                    appearanceSection
                    pairingSection
                }
                .formStyle(.grouped)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, idealWidth: 760, minHeight: 620, idealHeight: 760)
        .interactiveDismissDisabled(model.isDirty)
        .confirmationDialog(
            "Discard this theme draft?",
            isPresented: $model.showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Draft", role: .destructive) {
                model.discardDraft()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Unsaved theme changes will be lost.")
        }
        .confirmationDialog(
            "Confirm image rights",
            isPresented: $showsRightsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Export Theme") {
                rightsAccepted = true
                exportPendingTheme()
            }
            Button("Cancel", role: .cancel) { pendingExportURL = nil }
        } message: {
            Text("Export does not grant image rights. You confirm you may use and share this image.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintbrush.pointed.fill")
                .foregroundStyle(Color(habitatHex: model.color(for: .accent) ?? "#1687E8"))
            VStack(alignment: .leading, spacing: 2) {
                Text("Theme Studio")
                    .font(.headline)
                Text("Local Habitat theme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close")
            .accessibilityLabel("Close Theme Studio")
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
    }

    private var identitySection: some View {
        Section("Identity") {
            TextField("Theme name", text: $model.name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("theme-studio.name")
            if let message = model.nameValidationMessage {
                validation(message)
            }
            TextField("Author (optional)", text: $model.author)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("theme-studio.author")
            if let message = model.authorValidationMessage {
                validation(message)
            }
        }
    }

    private var backgroundSection: some View {
        Section("Background") {
            HStack(alignment: .top, spacing: 14) {
                preview
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: chooseImage) {
                        Label("Choose Image", systemImage: "photo")
                    }
                    .accessibilityIdentifier("theme-studio.choose-image")
                    if let sourceImageURL = model.sourceImageURL {
                        Text(sourceImageURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let message = model.imageValidationMessage {
                        validation(message)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var paletteSection: some View {
        Section("Palette") {
            if model.palette == nil {
                Text("Choose an image to generate a starting palette.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 138), spacing: 12)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(ThemePaletteRole.allCases, id: \.self) { role in
                        ColorPicker(role.title, selection: colorBinding(role), supportsOpacity: false)
                    }
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Style", selection: Binding(
                get: { model.styleFamily },
                set: { model.setStyleFamily($0) }
            )) {
                ForEach(HabitatThemeStyleFamily.allCases, id: \.self) { family in
                    Text(family.shortTitle).tag(family)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            Picker("Density", selection: Binding(
                get: { model.density },
                set: { model.setDensity($0) }
            )) {
                Text("Compact").tag(HabitatThemeDensity.compact)
                Text("Comfortable").tag(HabitatThemeDensity.comfortable)
            }
            .pickerStyle(.segmented)

            Picker("Safe side", selection: Binding(
                get: { model.safeSide },
                set: { model.setSafeSide($0) }
            )) {
                Text("Leading").tag(HabitatThemeSafeSide.leading)
                Text("Trailing").tag(HabitatThemeSafeSide.trailing)
                Text("Center").tag(HabitatThemeSafeSide.center)
                Text("None").tag(HabitatThemeSafeSide.none)
            }
            .pickerStyle(.segmented)

            Picker("Home treatment", selection: Binding(
                get: { model.homeMode },
                set: { model.setHomeMode($0) }
            )) {
                Text("Immersive").tag(HabitatThemeHomeMode.immersive)
                Text("Framed").tag(HabitatThemeHomeMode.framed)
                Text("Quiet").tag(HabitatThemeHomeMode.quiet)
            }
            .pickerStyle(.segmented)

            Picker("Task treatment", selection: Binding(
                get: { model.taskMode },
                set: { model.setTaskMode($0) }
            )) {
                Text("Ambient").tag(HabitatThemeTaskMode.ambient)
                Text("Banner").tag(HabitatThemeTaskMode.banner)
                Text("Off").tag(HabitatThemeTaskMode.off)
            }
            .pickerStyle(.segmented)

            Picker("Chrome material", selection: Binding(
                get: { model.chromeMaterial },
                set: { model.setChromeMaterial($0) }
            )) {
                Text("Solid").tag(HabitatThemeChromeMaterial.solid)
                Text("Tinted").tag(HabitatThemeChromeMaterial.tinted)
                Text("Glass").tag(HabitatThemeChromeMaterial.glass)
            }
            .pickerStyle(.segmented)

            valueSlider(
                "Background strength",
                value: model.backgroundStrength,
                range: 0.10...0.70,
                step: 0.01,
                format: "%.0f%%",
                setter: model.setBackgroundStrength,
                displayScale: 100
            )
            valueSlider(
                "Panel opacity",
                value: model.panelOpacity,
                range: 0.65...1.0,
                step: 0.01,
                format: "%.0f%%",
                setter: model.setPanelOpacity,
                displayScale: 100
            )
            valueSlider(
                "Home strength",
                value: model.homeStrength,
                range: 0.10...0.85,
                step: 0.01,
                format: "%.0f%%",
                setter: model.setHomeStrength,
                displayScale: 100
            )
            valueSlider(
                "Task strength",
                value: model.taskStrength,
                range: 0.10...0.85,
                step: 0.01,
                format: "%.0f%%",
                setter: model.setTaskStrength,
                displayScale: 100
            )
            valueSlider(
                "Sidebar opacity",
                value: model.sidebarOpacity,
                range: 0.40...1.0,
                step: 0.01,
                format: "%.0f%%",
                setter: model.setSidebarOpacity,
                displayScale: 100
            )
            valueSlider(
                "Header opacity",
                value: model.headerOpacity,
                range: 0.40...1.0,
                step: 0.01,
                format: "%.0f%%",
                setter: model.setHeaderOpacity,
                displayScale: 100
            )
            valueSlider(
                "Composer opacity",
                value: model.composerOpacity,
                range: 0.40...1.0,
                step: 0.01,
                format: "%.0f%%",
                setter: model.setComposerOpacity,
                displayScale: 100
            )
            valueSlider(
                "Blur",
                value: model.blurRadius,
                range: 0...24,
                step: 1,
                format: "%.0f pt",
                setter: model.setBlurRadius
            )
            valueSlider(
                "Focal point X",
                value: model.artFocus.x,
                range: 0...1,
                step: 0.01,
                format: "%.0f%%",
                setter: { model.setArtFocus(x: $0, y: model.artFocus.y) },
                displayScale: 100
            )
            valueSlider(
                "Focal point Y",
                value: model.artFocus.y,
                range: 0...1,
                step: 0.01,
                format: "%.0f%%",
                setter: { model.setArtFocus(x: model.artFocus.x, y: $0) },
                displayScale: 100
            )
        }
    }

    @ViewBuilder
    private var pairingSection: some View {
        if !model.availablePets.isEmpty {
            Section("Pet pairing") {
                Picker("Pet", selection: Binding(
                    get: { model.pairedPetID },
                    set: { model.setPairedPetID($0) }
                )) {
                    Text("None").tag(String?.none)
                    ForEach(model.availablePets) { pet in
                        Text(pet.name).tag(String?.some(pet.id))
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            stateLabel
            Spacer()
            Button("Cancel", action: close)
                .keyboardShortcut(.cancelAction)
            Button(action: beginExport) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(model.state == .saving)
            Button(action: saveLocally) {
                Label("Save Locally", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.state == .saving)
            .accessibilityIdentifier("theme-studio.save")
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
    }

    @ViewBuilder
    private var preview: some View {
        if let sourceImageURL = model.sourceImageURL, model.palette != nil {
            VStack(spacing: 7) {
                ThemeTreatmentPreview(
                    model: ThemeTreatmentPreviewModel(
                        appearance: model.previewAppearance,
                        surfaceHex: model.color(for: .surface) ?? "#101820",
                        panelHex: model.color(for: .panel) ?? "#182633",
                        panelAltHex: model.color(for: .panelAlt) ?? "#24384A",
                        textHex: model.color(for: .text) ?? "#F4FAFF",
                        accentHex: model.color(for: .accent) ?? "#16C6D9"
                    ),
                    imageURL: sourceImageURL,
                    symbol: "paintpalette.fill",
                    route: previewRoute,
                    height: 160
                )
                .frame(width: 300)

                Picker("Preview route", selection: $previewRoute) {
                    Text("Home").tag(ThemeTreatmentPreviewRoute.home)
                    Text("Task").tag(ThemeTreatmentPreviewRoute.task)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
            }
        } else {
            ZStack {
                Color.secondary.opacity(0.08)
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 300, height: 188)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch model.state {
        case .editing:
            EmptyView()
        case .saving:
            ProgressView()
                .controlSize(.small)
        case let .validationFailure(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    private func valueSlider(
        _ title: String,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        format: String,
        setter: @MainActor @escaping @Sendable (Double) -> Void,
        displayScale: Double = 1
    ) -> some View {
        HStack(spacing: 12) {
            Text(L10n.text(title))
                .frame(width: 138, alignment: .leading)
            Slider(
                value: Binding(get: { value }, set: { setter($0) }),
                in: range,
                step: step
            )
            Text(String(format: format, value * displayScale))
                .monospacedDigit()
                .frame(width: 54, alignment: .trailing)
        }
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
    }

    private func chooseImage() {
        guard let url = ResourcePackPanels.chooseThemeImage() else { return }
        try? model.selectImage(url)
    }

    private func saveLocally() {
        Task {
            await model.saveLocally()
            guard case let .saved(id) = model.state else { return }
            onSaved(id, model.pairedPetID)
            dismiss()
        }
    }

    private func beginExport() {
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
    var shortTitle: String {
        switch self {
        case .arcade: L10n.text("Arcade")
        case .retroMessenger: L10n.text("Retro")
        case .greenChat: L10n.text("Chat")
        case .classicDesktop: L10n.text("Classic")
        case .gameCinematic: L10n.text("Cinema")
        case .cozyWorld: L10n.text("Cozy")
        case .animeEnergy: L10n.text("Anime")
        case .fantasyAdventure: L10n.text("Fantasy")
        case .pixelWorld: L10n.text("Pixel")
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

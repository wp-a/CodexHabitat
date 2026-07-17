import AppKit
import ResourceKit
import SwiftUI

struct ThemesSettingsView: View {
    @ObservedObject var model: HabitatAppModel
    @State private var packageIDToRemove: String?
    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 12)]

    var body: some View {
        SettingsPage(
            "Themes",
            subtitle: "Native Habitat palettes independent from Codex theming"
        ) {
            HStack(spacing: 10) {
                Text("\(model.availableThemes.count) available")
                    .foregroundStyle(.secondary)
                Spacer()
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

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(model.availableThemes) { theme in
                    ThemeChoiceCard(
                        theme: theme,
                        isSelected: model.settings.selectedThemeID == theme.id,
                        action: { model.selectTheme(theme.id) }
                    )
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
        .onAppear(perform: model.refreshResources)
        .resourceReplacementConfirmation(model: model)
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
            .accessibilityLabel("Export \(package.manifest.name)")
            Button(role: .destructive, action: { packageIDToRemove = package.id }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove pack")
            .accessibilityLabel("Remove \(package.manifest.name)")
        }
        .padding(.vertical, 10)
    }

    private func importPack() {
        guard let url = ResourcePackPanels.chooseImport() else { return }
        Task { await model.importResourcePackage(from: url) }
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

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                if let previewURL = theme.previewURL,
                   let image = NSImage(contentsOf: previewURL) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 82)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                HStack {
                    Image(systemName: theme.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette[0])
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(color)
                                .frame(width: 13, height: 13)
                        }
                    }
                }
                Text(theme.name)
                    .font(.body.weight(.semibold))
                Text(theme.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 204, alignment: .topLeading)
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
        .accessibilityLabel(theme.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("themes.choice.\(theme.id)")
    }

    private var palette: [Color] {
        [
            Color(habitatHex: theme.accentHex),
            Color(habitatHex: theme.attentionHex),
            Color(habitatHex: theme.errorHex),
        ]
    }
}

import AppKit
import ResourceKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum ResourcePackPanels {
    static func chooseImport() -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.text("Import Habitat Pack")
        panel.prompt = L10n.text("Import")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [habitatPackType]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseExport(for package: InstalledPackage) -> URL? {
        let panel = NSSavePanel()
        panel.title = L10n.text("Export Habitat Pack")
        panel.prompt = L10n.text("Export")
        panel.allowedContentTypes = [habitatPackType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(package.id)-\(package.version).habitat-pack"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseThemeImage() -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.text("Choose Theme Background")
        panel.prompt = L10n.text("Choose")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .webP]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseThemeExport(name: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = L10n.text("Export Habitat Theme")
        panel.prompt = L10n.text("Export")
        panel.allowedContentTypes = [habitatPackType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(ThemePackageBuilder.safeID(for: name)).habitat-pack"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static var habitatPackType: UTType {
        UTType(filenameExtension: "habitat-pack", conformingTo: .zip) ?? .zip
    }
}

struct ResourceOperationStatusView: View {
    let state: ResourceLibraryOperationState

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .importing:
            status(L10n.text("Validating and importing..."), symbol: "arrow.down.circle", color: .secondary)
        case let .imported(name):
            status(L10n.format("%@ imported", name), symbol: "checkmark.circle.fill", color: .green)
        case let .replacementRequired(filename):
            status(L10n.format("%@ is already installed", filename), symbol: "exclamationmark.circle.fill", color: .orange)
        case .exporting:
            status(L10n.text("Preparing export..."), symbol: "arrow.up.circle", color: .secondary)
        case let .exported(name):
            status(L10n.format("%@ exported", name), symbol: "checkmark.circle.fill", color: .green)
        case .uninstalling:
            status(L10n.text("Removing package..."), symbol: "trash", color: .secondary)
        case let .uninstalled(name):
            status(L10n.format("%@ removed", name), symbol: "checkmark.circle.fill", color: .green)
        case .failed:
            status(L10n.text("The package operation failed validation."), symbol: "xmark.octagon.fill", color: .red)
        }
    }

    private func status(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    func resourceReplacementConfirmation(model: HabitatAppModel) -> some View {
        confirmationDialog(
            L10n.text("Replace the installed package?"),
            isPresented: Binding(
                get: { model.pendingReplacementArchiveURL != nil },
                set: { if !$0 { model.cancelPendingResourceReplacement() } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.text("Replace Package"), role: .destructive) {
                Task { await model.replacePendingResourcePackage() }
            }
            Button(L10n.text("Cancel"), role: .cancel, action: model.cancelPendingResourceReplacement)
        } message: {
            Text(L10n.text("The imported package has the same ID and version. Replacing it updates only Habitat's local copy and does not modify Codex."))
        }
    }
}

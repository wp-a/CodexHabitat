import AppKit
import ResourceKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum ResourcePackPanels {
    static func chooseImport() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Import Habitat Pack"
        panel.prompt = "Import"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [habitatPackType]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseExport(for package: InstalledPackage) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Habitat Pack"
        panel.prompt = "Export"
        panel.allowedContentTypes = [habitatPackType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(package.id)-\(package.version).habitat-pack"
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
            status("Validating and importing...", symbol: "arrow.down.circle", color: .secondary)
        case let .imported(name):
            status("\(name) imported", symbol: "checkmark.circle.fill", color: .green)
        case let .replacementRequired(filename):
            status("\(filename) is already installed", symbol: "exclamationmark.circle.fill", color: .orange)
        case .exporting:
            status("Preparing export...", symbol: "arrow.up.circle", color: .secondary)
        case let .exported(name):
            status("\(name) exported", symbol: "checkmark.circle.fill", color: .green)
        case .uninstalling:
            status("Removing package...", symbol: "trash", color: .secondary)
        case let .uninstalled(name):
            status("\(name) removed", symbol: "checkmark.circle.fill", color: .green)
        case .failed:
            status("The package operation failed validation.", symbol: "xmark.octagon.fill", color: .red)
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
            "Replace the installed package?",
            isPresented: Binding(
                get: { model.pendingReplacementArchiveURL != nil },
                set: { if !$0 { model.cancelPendingResourceReplacement() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Replace Package", role: .destructive) {
                Task { await model.replacePendingResourcePackage() }
            }
            Button("Cancel", role: .cancel, action: model.cancelPendingResourceReplacement)
        } message: {
            Text("The imported package has the same ID and version. Replacing it updates only Habitat's local copy and does not modify Codex.")
        }
    }
}

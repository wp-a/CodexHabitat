import AppKit
import CodexConnector
import Foundation
import HabitatCore
import PetRuntime
import ResourceKit
import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    @StateObject private var diagnostics = DiagnosticsViewModel.live()
    @StateObject private var bridge = ThemeBridgeIntegrationModel.live()
    @State private var confirmsClear = false
    @State private var confirmsRestore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup("Checks") {
                diagnosticRow(
                    "Codex connection",
                    status: diagnostics.connectionStatus,
                    symbol: "network"
                ) {
                    Task { await diagnostics.testConnection() }
                }
                diagnosticRow(
                    "Resource library",
                    status: diagnostics.resourceStatus,
                    symbol: "shippingbox"
                ) {
                    Task { await diagnostics.validateResources() }
                }
            }

            Divider()

            SettingsGroup("Recovery") {
                LabeledContent("Official appearance") {
                    Text(bridge.statusText)
                        .foregroundStyle(.secondary)
                }
                Button {
                    confirmsRestore = true
                } label: {
                    Label(
                        DiagnosticRecovery.officialAppearanceTitle,
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .disabled(!bridge.canRestore)
                .accessibilityIdentifier("privacy.restore-official-appearance")
                .alert(
                    "Restore the official Codex appearance?",
                    isPresented: $confirmsRestore
                ) {
                    Button("Cancel", role: .cancel) {}
                    Button("Restore") {
                        Task {
                            await bridge.restore()
                            await diagnostics.recordThemeRestore(
                                succeeded: bridge.state == .ready
                            )
                        }
                    }
                } message: {
                    Text("Codex will close and reopen normally. Unsaved composer text may be lost.")
                }
            }

            Divider()

            SettingsGroup("Local data") {
                if let status = diagnostics.localDataStatus {
                    Label(status, systemImage: diagnostics.localDataSucceeded
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill")
                        .foregroundStyle(diagnostics.localDataSucceeded ? .green : .secondary)
                }
                HStack(spacing: 10) {
                    Button(action: chooseExportDestination) {
                        Label("Export Redacted Diagnostics", systemImage: "square.and.arrow.up")
                    }
                    .disabled(diagnostics.isBusy)
                    .accessibilityIdentifier("privacy.export-diagnostics")

                    Button(role: .destructive) {
                        confirmsClear = true
                    } label: {
                        Label("Clear Local Data", systemImage: "trash")
                    }
                    .disabled(diagnostics.isBusy)
                    .accessibilityIdentifier("privacy.clear-local-data")
                    .alert(
                        "Clear diagnostics and preview cache?",
                        isPresented: $confirmsClear
                    ) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear", role: .destructive) {
                            Task { await diagnostics.clearLocalData() }
                        }
                    } message: {
                        Text("Settings, installed resources, and Codex data will be kept.")
                    }
                }
            }
        }
        .task {
            await bridge.refresh()
            await diagnostics.refreshEventCount()
        }
    }

    private func diagnosticRow(
        _ title: String,
        status: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Label(status, systemImage: symbol)
                    .foregroundStyle(.secondary)
                Button(action: action) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .disabled(diagnostics.isBusy)
                .help("Run check")
                .accessibilityLabel("Check \(title)")
            }
        }
    }

    private func chooseExportDestination() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "Codex-Habitat-Diagnostics.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await diagnostics.export(to: url) }
    }
}

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published private(set) var connectionStatus = "Not checked"
    @Published private(set) var resourceStatus = "Not checked"
    @Published private(set) var localDataStatus: String?
    @Published private(set) var localDataSucceeded = true
    @Published private(set) var isBusy = false

    private let root: URL
    private let petRoot: URL
    private let store: DiagnosticStore
    private let appVersion: String?

    init(root: URL, petRoot: URL, appVersion: String?) {
        self.root = root
        self.petRoot = petRoot
        store = DiagnosticStore(root: AppDirectories(root: root).diagnostics)
        self.appVersion = appVersion
    }

    static func live(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> DiagnosticsViewModel {
        let root: URL
        if let configured = environment["CODEX_HABITAT_HOME"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !configured.isEmpty {
            root = URL(fileURLWithPath: configured, isDirectory: true)
        } else {
            let support = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.homeDirectoryForCurrentUser.appending(
                path: "Library/Application Support",
                directoryHint: .isDirectory
            )
            root = support.appending(path: "Codex Habitat", directoryHint: .isDirectory)
        }
        let version = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.1.0-dev"
        return DiagnosticsViewModel(
            root: root,
            petRoot: PetLibrary.petRoot(environment: environment),
            appVersion: version
        )
    }

    func refreshEventCount() async {
        do {
            let count = try await store.events().count
            localDataStatus = count == 1 ? "1 diagnostic event" : "\(count) diagnostic events"
            localDataSucceeded = true
        } catch {
            localDataStatus = "Diagnostics unavailable"
            localDataSucceeded = false
        }
    }

    func testConnection() async {
        guard !isBusy else { return }
        isBusy = true
        connectionStatus = "Checking"
        defer { isBusy = false }
        do {
            let salt = try EventHashSaltStore(
                root: root.appending(path: "Private", directoryHint: .isDirectory)
            ).loadOrCreate()
            let client = CodexControlClient(
                transport: ProcessTransport(),
                sanitizer: CodexEventSanitizer(salt: salt)
            )
            try await client.connect()
            await client.disconnect()
            connectionStatus = "Available"
            try await record(.codexConnector, .connectionAvailable)
        } catch {
            connectionStatus = "Unavailable"
            let code: DiagnosticCode = error is JSONRPCCodecError
                || error is WebSocketCodecError
                ? .protocolMismatch
                : .connectionUnavailable
            try? await record(.codexConnector, code)
        }
    }

    func validateResources() async {
        guard !isBusy else { return }
        isBusy = true
        resourceStatus = "Checking"
        defer { isBusy = false }
        let petRoot = petRoot
        let libraryRoot = root.appending(path: "Library", directoryHint: .isDirectory)
        let result = await Task.detached {
            let pets = (try? PetLibrary(root: petRoot).discover()) ?? []
            let invalid = pets.filter { $0.status != .valid }.count
            let packages = InstalledPackageLibrary(
                root: libraryRoot,
                runtimeVersion: "1.0.0"
            ).currentPackages()
            return (pets.count, invalid, packages.count)
        }.value
        if result.1 == 0 {
            resourceStatus = "\(result.0) pets, \(result.2) packs valid"
            try? await record(.resourceLibrary, .resourcesValidated)
        } else {
            resourceStatus = "\(result.1) resources need attention"
            try? await record(.resourceLibrary, .resourcesRejected)
        }
    }

    func recordThemeRestore(succeeded: Bool) async {
        try? await record(
            .themeBridge,
            succeeded ? .themeRestored : .themeRestoreFailed
        )
        localDataStatus = succeeded
            ? "Official appearance restored"
            : "Appearance restore failed"
        localDataSucceeded = succeeded
    }

    func export(to destination: URL) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let events = try await store.events()
            try DiagnosticExporter().export(events: events, to: destination)
            try await record(.application, .diagnosticsExported)
            localDataStatus = "Redacted diagnostics exported"
            localDataSucceeded = true
        } catch {
            localDataStatus = "Diagnostics export failed"
            localDataSucceeded = false
        }
    }

    func clearLocalData() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let root = root
            _ = try await Task.detached {
                try DiagnosticMaintenance(root: root).clearPreviewCache()
            }.value
            try await store.clear()
            localDataStatus = "Diagnostics and preview cache cleared"
            localDataSucceeded = true
        } catch {
            localDataStatus = "Local data could not be cleared"
            localDataSucceeded = false
        }
    }

    private func record(
        _ module: DiagnosticModule,
        _ code: DiagnosticCode
    ) async throws {
        try await store.record(DiagnosticEvent(
            module: module,
            code: code,
            appVersion: appVersion
        ))
    }
}

import AppKit
import SwiftUI

struct IntegrationsSettingsView: View {
    @ObservedObject var model: HabitatAppModel
    @ObservedObject private var bridge = ThemeBridgeIntegrationModel.shared
    @State private var confirmsRestart = false
    @State private var codexVariant = CodexThemeVariant.dark
    @State private var nativeThemeCopyStatus: String?

    var body: some View {
        SettingsPage(
            "Integrations",
            subtitle: "Local Codex connections and optional appearance bridge"
        ) {
            SettingsGroup("Codex") {
                LabeledContent("Control plane") {
                    Label("Auto-detect", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Access mode") {
                    Label("Read only", systemImage: "lock.fill")
                        .foregroundStyle(.green)
                }
            }

            Divider()

            SettingsGroup("Codex native theme") {
                Picker("Variant", selection: $codexVariant) {
                    Text("Light").tag(CodexThemeVariant.light)
                    Text("Dark").tag(CodexThemeVariant.dark)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("integrations.native-theme.variant")

                HStack(spacing: 10) {
                    Button(action: copyNativeTheme) {
                        Label("Copy Codex Theme", systemImage: "doc.on.clipboard")
                    }
                    .accessibilityIdentifier("integrations.native-theme.copy")
                    if let nativeThemeCopyStatus {
                        Label(L10n.text(nativeThemeCopyStatus), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Divider()

            SettingsGroup("Deep appearance bridge") {
                LabeledContent("Helper") {
                    HStack(spacing: 7) {
                        if bridge.isBusy {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: bridge.state == .active
                                ? "checkmark.shield.fill"
                                : "shield.lefthalf.filled")
                        }
                        Text(L10n.text(bridge.statusText))
                    }
                    .foregroundStyle(bridge.state == .active ? .green : .secondary)
                }

                if bridge.state == .active {
                    Button {
                        Task {
                            await bridge.restore()
                            model.setThemeBridgeEnabled(bridge.state == .active)
                        }
                    } label: {
                        Label("Restore Official Appearance", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(bridge.isBusy)
                    .accessibilityIdentifier("integrations.theme-bridge.restore")
                } else {
                    Button {
                        confirmsRestart = true
                    } label: {
                        Label("Apply Selected Theme to Codex", systemImage: "paintbrush")
                    }
                    .disabled(bridge.state != .ready || !model.selectedThemeSupportsCodexBridge)
                    .accessibilityIdentifier("integrations.theme-bridge.apply")
                }

                if !model.selectedThemeSupportsCodexBridge {
                    Label(
                        "Choose a built-in theme before applying it to Codex",
                        systemImage: "lock.shield"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            codexVariant = CodexThemeShareString.suggestedVariant(for: model.selectedTheme)
            await bridge.refresh()
            model.setThemeBridgeEnabled(bridge.state == .active)
        }
        .onChange(of: model.settings.selectedThemeID) { _, _ in
            codexVariant = CodexThemeShareString.suggestedVariant(for: model.selectedTheme)
            nativeThemeCopyStatus = nil
        }
        .alert(
            "Restart Codex with the selected theme?",
            isPresented: $confirmsRestart
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Restart and Apply") {
                Task {
                    await bridge.enable(themeID: model.settings.selectedThemeID)
                    model.setThemeBridgeEnabled(bridge.state == .active)
                }
            }
        } message: {
            Text("Codex will close and reopen on a local debugging port. Unsaved composer text may be lost. Restore closes the port and returns the official appearance.")
        }
    }

    private func copyNativeTheme() {
        let value = CodexThemeShareString.make(
            theme: model.selectedTheme,
            variant: codexVariant
        )
        guard !value.isEmpty else {
            nativeThemeCopyStatus = nil
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        nativeThemeCopyStatus = pasteboard.setString(value, forType: .string)
            ? "Theme copied"
            : nil
    }
}

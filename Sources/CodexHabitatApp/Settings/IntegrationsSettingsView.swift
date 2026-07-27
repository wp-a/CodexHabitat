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
                LabeledContent(L10n.text("Control plane")) {
                    Label(L10n.text("Auto-detect"), systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                }
                LabeledContent(L10n.text("Access mode")) {
                    Label(L10n.text("Read only"), systemImage: "lock.fill")
                        .foregroundStyle(.green)
                }
            }

            Divider()

            SettingsGroup("Codex native theme") {
                Picker(L10n.text("Variant"), selection: $codexVariant) {
                    Text(L10n.text("Light")).tag(CodexThemeVariant.light)
                    Text(L10n.text("Dark")).tag(CodexThemeVariant.dark)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("integrations.native-theme.variant")

                HStack(spacing: 10) {
                    Button(action: copyNativeTheme) {
                        Label(L10n.text("Copy Codex Theme"), systemImage: "doc.on.clipboard")
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
                LabeledContent(L10n.text("Helper")) {
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

                Button {
                    confirmsRestart = true
                } label: {
                    Label(L10n.text("Apply Selected Theme to Codex"), systemImage: "paintbrush")
                }
                .disabled(!bridge.canApply || !model.selectedThemeSupportsCodexBridge)
                .accessibilityIdentifier("integrations.theme-bridge.apply")

                if bridge.canRestore {
                    Button {
                        Task {
                            await bridge.restore()
                            if bridge.state == .ready {
                                model.setThemeBridgeActive(false)
                            }
                        }
                    } label: {
                        Label(L10n.text("Restore Official Appearance"), systemImage: "arrow.counterclockwise")
                    }
                    .disabled(bridge.isBusy)
                    .accessibilityIdentifier("integrations.theme-bridge.restore")
                }

                if !model.selectedThemeSupportsCodexBridge {
                    Label(
                        L10n.text("Choose a bridge-compatible theme before applying it to Codex"),
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
        }
        .onChange(of: model.settings.selectedThemeID) { _, _ in
            codexVariant = CodexThemeShareString.suggestedVariant(for: model.selectedTheme)
            nativeThemeCopyStatus = nil
        }
        .alert(
            bridge.state == .active
                ? L10n.text("Switch Codex to the selected theme?")
                : L10n.text("Restart Codex with the selected theme?"),
            isPresented: $confirmsRestart
        ) {
            Button(L10n.text("Cancel"), role: .cancel) {}
            Button(bridge.state == .active ? L10n.text("Switch Theme") : L10n.text("Restart and Apply")) {
                Task {
                    await bridge.enable(
                        themeID: model.settings.selectedThemeID,
                        approvedThemeIDs: model.codexBridgeThemeIDs
                    )
                    if bridge.activeThemeID == model.settings.selectedThemeID {
                        model.setThemeBridgeActive(
                            true,
                            themeID: model.settings.selectedThemeID
                        )
                    }
                }
            }
        } message: {
            Text(bridge.state == .active
                ? L10n.text("The current bridge theme will be replaced without restarting Codex.")
                : L10n.text("Codex will close and reopen on a local debugging port. Unsaved composer text may be lost. Restore closes the port and returns the official appearance."))
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

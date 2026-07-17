import SwiftUI

struct IntegrationsSettingsView: View {
    @ObservedObject var model: HabitatAppModel
    @StateObject private var bridge = ThemeBridgeIntegrationModel.live()
    @State private var confirmsRestart = false

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

            SettingsGroup("Appearance bridge") {
                LabeledContent("Helper") {
                    HStack(spacing: 7) {
                        if bridge.isBusy {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: bridge.state == .active
                                ? "checkmark.shield.fill"
                                : "shield.lefthalf.filled")
                        }
                        Text(bridge.statusText)
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
                    .disabled(bridge.state != .ready)
                    .accessibilityIdentifier("integrations.theme-bridge.apply")
                }
            }
        }
        .task {
            await bridge.refresh()
            model.setThemeBridgeEnabled(bridge.state == .active)
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
}

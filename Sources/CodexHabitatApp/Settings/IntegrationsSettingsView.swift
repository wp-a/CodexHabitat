import SwiftUI

struct IntegrationsSettingsView: View {
    @ObservedObject var model: HabitatAppModel

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
                Toggle(
                    "Enable optional CDP theme bridge",
                    isOn: Binding(
                        get: { model.settings.themeBridgeEnabled },
                        set: { model.setThemeBridgeEnabled($0) }
                    )
                )
                .disabled(true)
                .accessibilityIdentifier("integrations.theme-bridge")

                LabeledContent("Helper") {
                    Text("Not installed")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

import AppKit
import SwiftUI

struct PrivacySettingsView: View {
    @ObservedObject var model: HabitatAppModel

    var body: some View {
        SettingsPage(
            "Privacy",
            subtitle: "Local-first data boundaries and recovery"
        ) {
            SettingsGroup("Data access") {
                privacyRow("Cloud account", value: "Not required", symbol: "person.crop.circle.badge.xmark")
                privacyRow("Prompts and responses", value: "Never read", symbol: "text.badge.xmark")
                privacyRow("Project files", value: "Never read", symbol: "folder.badge.minus")
                privacyRow("Diagnostics", value: "Local and redacted", symbol: "checkmark.shield.fill")
            }

            Divider()

            SettingsGroup("First run") {
                Button(action: model.restartOnboarding) {
                    Label("Run setup again", systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("privacy.restart-onboarding")
            }

            Divider()

            DiagnosticsView()
        }
    }

    private func privacyRow(_ title: String, value: String, symbol: String) -> some View {
        LabeledContent(L10n.text(title)) {
            Label(L10n.text(value), systemImage: symbol)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

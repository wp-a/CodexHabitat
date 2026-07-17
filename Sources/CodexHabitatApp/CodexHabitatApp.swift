import AppKit
import HabitatCore
import SwiftUI

@MainActor
private enum HabitatAppEnvironment {
    static let model = HabitatAppModel.live()
    static let settingsWindowController = HabitatSettingsWindowController()
    static let desktopController = HabitatDesktopController()
    static let runtimeController = HabitatRuntimeController.live()
    static let updaterController = HabitatUpdaterController()
}

@MainActor
private final class HabitatApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            let model = HabitatAppEnvironment.model
            await model.load()
            HabitatAppEnvironment.desktopController.bind(to: model)
            HabitatAppEnvironment.runtimeController.start(
                desktopController: HabitatAppEnvironment.desktopController
            )
            let shouldShowSettings = model.requiresOnboarding
                || CommandLine.arguments.contains("--show-settings")
            guard shouldShowSettings else { return }
            if let sectionFlag = CommandLine.arguments.firstIndex(
                of: "--show-settings-section"
            ), CommandLine.arguments.indices.contains(sectionFlag + 1),
               let section = SettingsSection(
                rawValue: CommandLine.arguments[sectionFlag + 1]
               ) {
                model.selectedSettingsSection = section
            }
            try? await Task.sleep(for: .milliseconds(180))
            HabitatAppEnvironment.settingsWindowController.show(model: model)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { @MainActor in
            await HabitatAppEnvironment.runtimeController.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

struct CodexHabitatGUI: App {
    @NSApplicationDelegateAdaptor(HabitatApplicationDelegate.self) private var appDelegate
    @StateObject private var model = HabitatAppEnvironment.model

    var body: some Scene {
        MenuBarExtra("Codex Habitat", systemImage: "pawprint.fill") {
            HabitatMenuBarView(model: model)
        }
        .menuBarExtraStyle(.window)

    }
}

private struct HabitatMenuBarView: View {
    @ObservedObject var model: HabitatAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Codex Habitat")
                        .font(.headline)
                    Text(model.settings.selectedThemeID.replacingOccurrences(of: "-", with: " ").capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(model.isLoaded ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(model.isLoaded ? "Ready" : "Loading")
            }

            Divider()

            Toggle("Show Habitat", isOn: $model.isHabitatVisible)
                .toggleStyle(.switch)
                .accessibilityIdentifier("menu.show-habitat")

            Button(action: openSettings) {
                Label("Settings…", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu.settings")

            if HabitatAppEnvironment.updaterController.isAvailable {
                Button(action: HabitatAppEnvironment.updaterController.checkForUpdates) {
                    Label("Check for Updates…", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("menu.check-for-updates")
            }

            Divider()

            Button(action: { NSApp.terminate(nil) }) {
                Label("Quit Codex Habitat", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .accessibilityIdentifier("menu.quit")
        }
        .padding(14)
        .frame(width: 260)
        .task {
            await model.load()
        }
    }

    private func openSettings() {
        HabitatAppEnvironment.settingsWindowController.show(model: model)
    }
}

@main
enum CodexHabitatEntryPoint {
    @MainActor
    static func main() async {
        if CommandLine.arguments.dropFirst() == ["--version"] {
            let version = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? HabitatCore.version
            print("Codex Habitat \(version)")
            return
        }
        if CommandLine.arguments.contains("--doctor-codex") {
            let status = await CodexDoctor.run()
            exit(status)
        }
        if CommandLine.arguments.contains("--doctor-pets") {
            let status = PetDoctor.run()
            exit(status)
        }
        if CommandLine.arguments.contains("--preview-overlay") {
            let themeID: String?
            if let themeIndex = CommandLine.arguments.firstIndex(of: "--preview-theme"),
               CommandLine.arguments.indices.contains(themeIndex + 1) {
                themeID = CommandLine.arguments[themeIndex + 1]
            } else {
                themeID = nil
            }
            OverlayPreview.run(themeID: themeID)
            return
        }
        if let previewPetIndex = CommandLine.arguments.firstIndex(of: "--preview-pet"),
           CommandLine.arguments.indices.contains(previewPetIndex + 1) {
            let status = PetPreview.run(id: CommandLine.arguments[previewPetIndex + 1])
            exit(status)
        }
        CodexHabitatGUI.main()
    }
}

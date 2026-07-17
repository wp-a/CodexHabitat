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
            HabitatAppEnvironment.desktopController.onOpenSettings = {
                HabitatAppEnvironment.settingsWindowController.show(model: model)
            }
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
            HabitatMenuBarView(
                model: model,
                desktopController: HabitatAppEnvironment.desktopController
            )
        }
        .menuBarExtraStyle(.window)

    }
}

private struct HabitatMenuBarView: View {
    @ObservedObject var model: HabitatAppModel
    @ObservedObject var desktopController: HabitatDesktopController

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

            connectionRow

            Toggle("Show Habitat", isOn: $model.isHabitatVisible)
                .toggleStyle(.switch)
                .accessibilityIdentifier("menu.show-habitat")

            Button(action: toggleMoveMode) {
                let moveMode = HabitatMoveModePresentation(
                    isActive: desktopController.isTemporaryMoveMode
                )
                Label(moveMode.title, systemImage: moveMode.symbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(!desktopController.isVisible)
            .accessibilityIdentifier("menu.move-habitat")

            if model.settings.widgetOrder.contains(.pomodoro)
                || model.settings.widgetOrder.contains(.countdown) {
                Divider()
                HabitatMenuTimerControls(
                    model: desktopController.widgetModel,
                    showsPomodoro: model.settings.widgetOrder.contains(.pomodoro),
                    showsCountdown: model.settings.widgetOrder.contains(.countdown)
                )
            }

            Divider()
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
        .frame(width: 292)
        .task {
            await model.load()
        }
    }

    private func openSettings() {
        HabitatAppEnvironment.settingsWindowController.show(model: model)
    }

    private func toggleMoveMode() {
        if desktopController.isTemporaryMoveMode {
            desktopController.endTemporaryMoveMode()
        } else {
            desktopController.beginTemporaryMoveMode()
        }
    }

    private var connectionRow: some View {
        let connection = HabitatMenuConnectionPresentation(
            health: desktopController.currentSnapshot.connectionHealth
        )
        return HStack(spacing: 9) {
            Image(systemName: connection.symbol)
                .foregroundStyle(connectionTint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(connection.title)
                    .font(.subheadline.weight(.medium))
                Text(activityTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(connection.badge)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(connectionTint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("menu.connection")
    }

    private var connectionTint: Color {
        switch desktopController.currentSnapshot.connectionHealth {
        case .online: .teal
        case .estimated, .reconnecting: .orange
        case .offline: .secondary
        }
    }

    private var activityTitle: String {
        switch desktopController.currentSnapshot.activity {
        case .resting: "Codex resting"
        case .working: "Codex working"
        case .attention: "Review requested"
        case .succeeded: "Task complete"
        case .failed: "Needs attention"
        case .offline: "No activity available"
        }
    }
}

struct HabitatMenuConnectionPresentation: Equatable {
    let title: String
    let badge: String
    let symbol: String

    init(health: ConnectionHealth) {
        switch health {
        case .online:
            (title, badge, symbol) = ("Connected", "LIVE", "network")
        case .estimated:
            (title, badge, symbol) = ("Local activity estimate", "EST.", "waveform.path.ecg")
        case .reconnecting:
            (title, badge, symbol) = (
                "Reconnecting",
                "RETRY",
                "arrow.trianglehead.2.clockwise.rotate.90"
            )
        case .offline:
            (title, badge, symbol) = ("Disconnected", "OFF", "network.slash")
        }
    }
}

struct HabitatMoveModePresentation: Equatable {
    let title: String
    let symbol: String

    init(isActive: Bool) {
        if isActive {
            (title, symbol) = ("Finish Moving", "checkmark")
        } else {
            (title, symbol) = (
                "Move Habitat",
                "arrow.up.and.down.and.arrow.left.and.right"
            )
        }
    }
}

private struct HabitatMenuTimerControls: View {
    @ObservedObject var model: WidgetRailModel
    let showsPomodoro: Bool
    let showsCountdown: Bool

    var body: some View {
        VStack(spacing: 8) {
            if showsPomodoro {
                timerRow(
                    title: model.pomodoroSnapshot.phase == .rest ? "Rest" : "Focus",
                    duration: model.pomodoroSnapshot.remainingSeconds,
                    isRunning: model.pomodoroSnapshot.isRunning,
                    tint: .pink,
                    toggle: model.togglePomodoro,
                    reset: model.resetPomodoro
                )
            }
            if showsCountdown {
                timerRow(
                    title: "Countdown",
                    duration: model.countdownSnapshot.remainingSeconds,
                    isRunning: model.countdownSnapshot.isRunning,
                    tint: .teal,
                    toggle: model.toggleCountdown,
                    reset: model.resetCountdown
                )
            }
        }
    }

    private func timerRow(
        title: String,
        duration: Int,
        isRunning: Bool,
        tint: Color,
        toggle: @escaping () -> Void,
        reset: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: title == "Countdown" ? "hourglass" : "timer")
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formattedDuration(duration))
                    .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
            }
            Spacer()
            menuTimerButton(
                systemImage: isRunning ? "pause.fill" : "play.fill",
                label: isRunning ? "Pause \(title)" : "Start \(title)",
                action: toggle
            )
            menuTimerButton(
                systemImage: "arrow.counterclockwise",
                label: "Reset \(title)",
                action: reset
            )
        }
    }

    private func menuTimerButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
        .help(label)
        .accessibilityLabel(label)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
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

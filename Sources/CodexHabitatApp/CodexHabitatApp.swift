import AppKit
import HabitatCore
import SwiftUI

@MainActor
private enum HabitatAppEnvironment {
    static let visualQAOptions = HabitatVisualQALaunchOptions.current
    static let model = HabitatAppModel.live()
    static let settingsWindowController = HabitatSettingsWindowController()
    static let desktopController = HabitatDesktopController(
        isWidgetRailExpanded: !visualQAOptions.collapsesOverlay
    )
    static let runtimeController = HabitatRuntimeController.live()
    static let updaterController = HabitatUpdaterController()
}

struct HabitatLaunchContext: Equatable {
    let launchedAsLoginItem: Bool

    init(event: NSAppleEventDescriptor?) {
        launchedAsLoginItem = event?.paramDescriptor(
            forKeyword: AEKeyword(keyAELaunchedAsLogInItem)
        ) != nil
    }
}

enum HabitatLaunchPresentation {
    static func shouldShowSettings(
        launchedAsLoginItem: Bool,
        requiresOnboarding: Bool,
        arguments: [String]
    ) -> Bool {
        requiresOnboarding
            || arguments.contains("--show-settings")
            || !launchedAsLoginItem
    }
}

struct HabitatBridgeLaunchPolicy: Equatable {
    let allowsStatusRefresh: Bool
    let allowsWatcherResume: Bool
    let allowsPersistentBridgeStateMutation: Bool

    init(arguments: [String], environment: [String: String]) {
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        let isVisualQA = arguments.contains("--visual-qa")
        allowsStatusRefresh = !isRunningTests
        allowsWatcherResume = !isRunningTests && !isVisualQA
        allowsPersistentBridgeStateMutation = !isRunningTests && !isVisualQA
    }
}

struct HabitatBridgeTerminationPolicy: Equatable {
    let allowsAppearanceRestore: Bool
    let allowsPersistentBridgeStateMutation: Bool

    init(arguments: [String], environment: [String: String]) {
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        let isVisualQA = arguments.contains("--visual-qa")
        allowsAppearanceRestore = !isRunningTests && !isVisualQA
        allowsPersistentBridgeStateMutation = !isRunningTests && !isVisualQA
    }
}

@MainActor
enum HabitatLaunchSequence {
    static func start(
        shouldPresentSettings: Bool,
        presentSettings: () -> Void,
        bridgeWork: @escaping @MainActor @Sendable () async -> Void
    ) -> Task<Void, Never> {
        if shouldPresentSettings {
            presentSettings()
        }
        return Task {
            await bridgeWork()
        }
    }
}

@MainActor
final class HabitatApplicationDelegate: NSObject, NSApplicationDelegate {
    private let reopenAction: () -> Void
    private var launchContext = HabitatLaunchContext(event: nil)
    private var bridgeLaunchTask: Task<Void, Never>?

    override init() {
        reopenAction = {
            HabitatAppEnvironment.settingsWindowController.show(
                model: HabitatAppEnvironment.model,
                desktopController: HabitatAppEnvironment.desktopController
            )
        }
        super.init()
    }

    init(reopenAction: @escaping () -> Void) {
        self.reopenAction = reopenAction
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchContext = HabitatLaunchContext(
            event: NSAppleEventManager.shared().currentAppleEvent
        )
        if launchContext.launchedAsLoginItem {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            let model = HabitatAppEnvironment.model
            await model.load()
            HabitatAppEnvironment.desktopController.onOpenSettings = {
                HabitatAppEnvironment.settingsWindowController.show(
                    model: model,
                    desktopController: HabitatAppEnvironment.desktopController
                )
            }
            HabitatAppEnvironment.desktopController.bind(to: model)
            HabitatAppEnvironment.runtimeController.start(
                desktopController: HabitatAppEnvironment.desktopController
            )
            let shouldShowSettings = HabitatLaunchPresentation.shouldShowSettings(
                launchedAsLoginItem: self.launchContext.launchedAsLoginItem,
                requiresOnboarding: model.requiresOnboarding,
                arguments: CommandLine.arguments
            )
            if let sectionFlag = CommandLine.arguments.firstIndex(
                of: "--show-settings-section"
            ), CommandLine.arguments.indices.contains(sectionFlag + 1),
               let section = SettingsSection(
                rawValue: CommandLine.arguments[sectionFlag + 1]
                ) {
                model.selectedSettingsSection = section
            }
            let bridge = ThemeBridgeIntegrationModel.shared
            let bridgePolicy = HabitatBridgeLaunchPolicy(
                arguments: CommandLine.arguments,
                environment: ProcessInfo.processInfo.environment
            )
            self.bridgeLaunchTask?.cancel()
            self.bridgeLaunchTask = HabitatLaunchSequence.start(
                shouldPresentSettings: shouldShowSettings,
                presentSettings: {
                    HabitatAppEnvironment.settingsWindowController.show(
                        model: model,
                        desktopController: HabitatAppEnvironment.desktopController
                    )
                },
                bridgeWork: {
                    guard bridgePolicy.allowsStatusRefresh else { return }
                    await bridge.refresh()
                    guard !Task.isCancelled else { return }
                    if bridge.state == .ready {
                        if bridgePolicy.allowsPersistentBridgeStateMutation {
                            model.setThemeBridgeActive(false)
                        }
                        return
                    }
                    guard bridgePolicy.allowsWatcherResume,
                          model.settings.themeBridgeEnabled,
                          let bridgeThemeID = model.settings.bridgeThemeID,
                          model.codexBridgeThemeIDs.contains(bridgeThemeID)
                    else {
                        return
                    }
                    await bridge.resumeWatching(
                        themeID: bridgeThemeID,
                        approvedThemeIDs: model.codexBridgeThemeIDs
                    )
                    guard !Task.isCancelled else { return }
                    if bridge.state == .active {
                        model.setThemeBridgeActive(true, themeID: bridge.activeThemeID)
                    }
                }
            )
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        bridgeLaunchTask?.cancel()
        bridgeLaunchTask = nil
        ThemeBridgeIntegrationModel.shared.cancelRefresh()
        let bridgeTerminationPolicy = HabitatBridgeTerminationPolicy(
            arguments: CommandLine.arguments,
            environment: ProcessInfo.processInfo.environment
        )
        Task { @MainActor in
            await HabitatAppEnvironment.runtimeController.stop()
            if bridgeTerminationPolicy.allowsAppearanceRestore {
                await ThemeBridgeIntegrationModel.shared.restoreForApplicationTermination()
            }
            if bridgeTerminationPolicy.allowsPersistentBridgeStateMutation,
               ThemeBridgeIntegrationModel.shared.state == .ready {
                HabitatAppEnvironment.model.setThemeBridgeActive(false)
            }
            await HabitatAppEnvironment.model.flushSettings()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        reopenAction()
        return true
    }
}

struct CodexHabitatGUI: App {
    @NSApplicationDelegateAdaptor(HabitatApplicationDelegate.self) private var appDelegate
    @StateObject private var model = HabitatAppEnvironment.model

    var body: some Scene {
        MenuBarExtra {
            HabitatMenuBarView(
                model: model,
                desktopController: HabitatAppEnvironment.desktopController
            )
        } label: {
            HabitatMenuBarLabel(
                desktopController: HabitatAppEnvironment.desktopController
            )
        }
        .menuBarExtraStyle(.window)

    }
}

struct HabitatMenuBarStatusPresentation: Equatable {
    let symbol: String
    let accessibilityTitle: String

    init(activity: AgentActivity) {
        switch activity {
        case .offline:
            (symbol, accessibilityTitle) = ("pawprint", "No activity available")
        case .resting:
            (symbol, accessibilityTitle) = ("pawprint.fill", "Codex resting")
        case .working:
            (symbol, accessibilityTitle) = ("pawprint.circle.fill", "Codex working")
        case .attention:
            (symbol, accessibilityTitle) = ("exclamationmark.bubble.fill", "Review requested")
        case .succeeded:
            (symbol, accessibilityTitle) = ("checkmark.circle.fill", "Task complete")
        case .failed:
            (symbol, accessibilityTitle) = ("exclamationmark.triangle.fill", "Needs attention")
        }
    }
}

private struct HabitatMenuBarLabel: View {
    @ObservedObject var desktopController: HabitatDesktopController

    var body: some View {
        let presentation = HabitatMenuBarStatusPresentation(
            activity: desktopController.currentSnapshot.activity
        )
        Image(systemName: presentation.symbol)
            .accessibilityLabel(L10n.text(presentation.accessibilityTitle))
    }
}

private struct HabitatMenuBarView: View {
    @ObservedObject var model: HabitatAppModel
    @ObservedObject var desktopController: HabitatDesktopController
    @ObservedObject private var progression = CompanionProgressionStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(L10n.text("Codex Habitat"))
                            .font(.headline)
                        Text(L10n.format("Lv.%d", progression.snapshot.level))
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.yellow.opacity(0.16), in: Capsule())
                    }
                    Text(L10n.text(model.selectedTheme.name))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(model.isLoaded ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(L10n.text(model.isLoaded ? "Ready" : "Loading"))
            }

            Divider()

            connectionRow

            multiAgentCompactRow

            telemetrySummarySection

            usageSection

            Toggle(L10n.text("Show Habitat"), isOn: $model.isHabitatVisible)
                .toggleStyle(.switch)
                .accessibilityIdentifier("menu.show-habitat")

            if desktopController.isVisible {
                HStack(spacing: 8) {
                    Button(action: desktopController.patPet) {
                        Label(L10n.text("Pat Companion"), systemImage: "hand.wave.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityIdentifier("menu.pat-companion")

                    Button(action: desktopController.feedSnack) {
                        Label(L10n.text("Feed Energy"), systemImage: "bolt.heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                    Button {
                        desktopController.snapToPreset(.notchIsland)
                    } label: {
                        Image(systemName: "menubar.dock.rectangle")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .help(L10n.text("Notch Island"))
                }
            }

            Button(action: toggleMoveMode) {
                let moveMode = HabitatMoveModePresentation(
                    isActive: desktopController.isTemporaryMoveMode
                )
                Label(L10n.text(moveMode.title), systemImage: moveMode.symbol)
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
                Label(L10n.text("Settings…"), systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu.settings")

            if HabitatAppEnvironment.updaterController.isAvailable {
                Button(action: HabitatAppEnvironment.updaterController.checkForUpdates) {
                    Label(L10n.text("Check for Updates…"), systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("menu.check-for-updates")
            }

            Divider()

            Button(action: { NSApp.terminate(nil) }) {
                Label(L10n.text("Quit Codex Habitat"), systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .accessibilityIdentifier("menu.quit")
        }
        .padding(14)
        .frame(width: 308)
        .task {
            await model.load()
            progression.refreshIfNeeded()
        }
    }

    private func openSettings() {
        HabitatAppEnvironment.settingsWindowController.show(
            model: model,
            desktopController: desktopController
        )
    }

    private func toggleMoveMode() {
        if desktopController.isTemporaryMoveMode {
            desktopController.endTemporaryMoveMode()
        } else {
            desktopController.beginTemporaryMoveMode()
        }
    }

    private var multiAgentCompactRow: some View {
        HStack(spacing: 6) {
            ForEach(progression.snapshot.agents) { agent in
                let tint = Color(habitatHex: agent.tintHex)
                HStack(spacing: 4) {
                    Circle()
                        .fill(agent.status == .notDetected ? Color.secondary.opacity(0.35) : tint)
                        .frame(width: 5.5, height: 5.5)
                    Text(agent.id == "codex" ? "Codex" : (agent.id == "claude" ? "Claude" : "Gemini"))
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                    if agent.sessionCount > 0 {
                        Text("\(agent.sessionCount)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 6.5)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var telemetrySummarySection: some View {
        if let metrics = desktopController.currentSnapshot.tokenMetrics {
            HStack(spacing: 8) {
                menuMetricPill(
                    title: L10n.text("Latest request"),
                    value: metrics.latestRequestTokens.map(WidgetRailView.compactCount) ?? "--"
                )
                menuMetricPill(
                    title: L10n.text("Context"),
                    value: metrics.contextUsedPercent.map { "\(Int($0.rounded()))%" } ?? "--"
                )
                menuMetricPill(
                    title: L10n.text("Task cumulative"),
                    value: WidgetRailView.compactCount(metrics.taskCumulativeTokens)
                )
            }
        }
    }

    private func menuMetricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var usageSection: some View {
        let snapshot = desktopController.currentSnapshot
        let primary = snapshot.primaryRateLimit
        let secondary = snapshot.secondaryRateLimit
        if primary?.usedPercent != nil || secondary?.usedPercent != nil {
            VStack(spacing: 6) {
                quotaRow(titleKey: "5-hour limit", limit: primary)
                quotaRow(titleKey: "Weekly limit", limit: secondary)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.text("Account usage"))
        }
    }

    @ViewBuilder
    private func quotaRow(titleKey: String, limit: RateLimitSummary?) -> some View {
        if let usedPercent = limit?.usedPercent {
            let percent = min(max(usedPercent, 0), 100)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(L10n.text(titleKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(quotaDetailText(percent: percent, resetAt: limit?.resetAt))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: percent, total: 100)
                    .progressViewStyle(.linear)
                    .controlSize(.small)
                    .tint(percent >= 90 ? .orange : .teal)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.text(titleKey))
            .accessibilityValue(quotaDetailText(percent: percent, resetAt: limit?.resetAt))
        }
    }

    private func quotaDetailText(percent: Double, resetAt: Date?) -> String {
        let used = "\(Int(percent.rounded()))%"
        guard let reset = WidgetRailView.quotaResetText(resetAt) else { return used }
        return "\(used) · \(reset)"
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
                Text(L10n.text(connection.title))
                    .font(.subheadline.weight(.medium))
                Text(L10n.text(activityTitle))
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
                Text(L10n.text(title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formattedDuration(duration))
                    .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
            }
            Spacer()
            menuTimerButton(
                systemImage: isRunning ? "pause.fill" : "play.fill",
                label: L10n.format(isRunning ? "Pause %@" : "Start %@", L10n.text(title)),
                action: toggle
            )
            menuTimerButton(
                systemImage: "arrow.counterclockwise",
                label: L10n.format("Reset %@", L10n.text(title)),
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
        _ = HabitatVisualQALaunchOptions.current
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
            let status = await PetPreview.run(id: CommandLine.arguments[previewPetIndex + 1])
            exit(status)
        }
        CodexHabitatGUI.main()
    }
}

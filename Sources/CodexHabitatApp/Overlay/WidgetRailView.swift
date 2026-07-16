import HabitatCore
import SwiftUI
import WidgetRuntime

@MainActor
final class WidgetRailModel: ObservableObject {
    @Published private(set) var snapshot: HabitatSnapshot
    @Published private(set) var pomodoroSnapshot: PomodoroSnapshot

    private var pomodoro: PomodoroTimer
    private var ticker: Task<Void, Never>?

    init(
        snapshot: HabitatSnapshot = HabitatSnapshot(),
        configuration: PomodoroConfiguration = PomodoroConfiguration()
    ) {
        self.snapshot = snapshot
        do {
            var timer = try PomodoroTimer(configuration: configuration)
            pomodoroSnapshot = timer.snapshot()
            pomodoro = timer
        } catch {
            preconditionFailure("The built-in Pomodoro configuration must be valid")
        }
    }

    deinit {
        ticker?.cancel()
    }

    func apply(_ snapshot: HabitatSnapshot) {
        self.snapshot = snapshot
    }

    func togglePomodoro() {
        if pomodoroSnapshot.isRunning {
            pomodoro.pause()
            ticker?.cancel()
            ticker = nil
        } else {
            pomodoro.start()
            beginTicking()
        }
        refreshPomodoro()
    }

    func resetPomodoro() {
        ticker?.cancel()
        ticker = nil
        pomodoro.reset()
        refreshPomodoro()
    }

    private func beginTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.refreshPomodoro()
            }
        }
    }

    private func refreshPomodoro() {
        pomodoroSnapshot = pomodoro.snapshot()
    }
}

struct WidgetRailView: View {
    @ObservedObject var model: WidgetRailModel
    let enabledWidgets: [WidgetIdentifier]
    let theme: HabitatThemeDescriptor

    init(
        model: WidgetRailModel,
        enabledWidgets: [WidgetIdentifier] = HabitatSettings.default.widgetOrder,
        theme: HabitatThemeDescriptor = HabitatThemeDescriptor.builtIn[0]
    ) {
        self.model = model
        self.enabledWidgets = enabledWidgets
        self.theme = theme
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(enabledWidgets.enumerated()), id: \.element) { index, id in
                row(for: id)
                if index < enabledWidgets.count - 1 {
                    Divider()
                        .overlay(textColor.opacity(0.13))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(
            width: HabitatOverlayLayout.widgetRailSize.width,
            height: HabitatOverlayLayout.widgetRailSize.height
        )
        .foregroundStyle(textColor)
        .background(surfaceColor.opacity(0.96), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(textColor.opacity(0.13), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Habitat widgets")
    }

    @ViewBuilder
    private func row(for id: WidgetIdentifier) -> some View {
        switch id {
        case .status:
            statusRow
        case .usage:
            usageRow
        case .clock:
            clockRow
        case .pomodoro:
            pomodoroRow
        case .countdown:
            countdownRow
        }
    }

    private var statusRow: some View {
        WidgetRow(systemImage: statusSymbol, tint: statusColor) {
            Text(statusTitle)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Circle()
                .fill(connectionColor)
                .frame(width: 7, height: 7)
                .accessibilityLabel(connectionTitle)
        }
    }

    private var usageRow: some View {
        WidgetRow(systemImage: "gauge.with.dots.needle.50percent", tint: accentColor) {
            Gauge(value: usagePercent, in: 0...100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinear)
            .tint(accentColor)
            .accessibilityLabel("Primary usage")
            .accessibilityValue(usageValue)

            Text(usageValue)
                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(textColor.opacity(0.62))
                .frame(width: 32, alignment: .trailing)
        }
    }

    private var clockRow: some View {
        WidgetRow(systemImage: "clock.fill", tint: attentionColor) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .accessibilityLabel("Local time")
            }
            Spacer(minLength: 0)
        }
    }

    private var pomodoroRow: some View {
        HStack(spacing: 8) {
            Image(systemName: model.pomodoroSnapshot.phase == .rest ? "cup.and.saucer.fill" : "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(errorColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.pomodoroSnapshot.phase == .rest ? "REST" : "FOCUS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(textColor.opacity(0.62))
                Text(formattedDuration(model.pomodoroSnapshot.remainingSeconds))
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            timerButton(
                systemImage: model.pomodoroSnapshot.isRunning ? "pause.fill" : "play.fill",
                label: model.pomodoroSnapshot.isRunning ? "Pause focus timer" : "Start focus timer",
                identifier: "widgets.pomodoro.toggle",
                action: model.togglePomodoro
            )
            timerButton(
                systemImage: "arrow.counterclockwise",
                label: "Reset focus timer",
                identifier: "widgets.pomodoro.reset",
                action: model.resetPomodoro
            )
        }
        .frame(height: 44)
    }

    private var countdownRow: some View {
        WidgetRow(systemImage: "hourglass", tint: accentColor) {
            Text("05:00")
                .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                .accessibilityLabel("Countdown, five minutes")
            Spacer(minLength: 0)
        }
    }

    private func timerButton(
        systemImage: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(textColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var usagePercent: Double {
        min(max(model.snapshot.primaryRateLimit?.usedPercent ?? 0, 0), 100)
    }

    private var usageValue: String {
        guard model.snapshot.primaryRateLimit?.usedPercent != nil else { return "--" }
        return "\(Int(usagePercent.rounded()))%"
    }

    private var statusSymbol: String {
        switch model.snapshot.activity {
        case .resting: "moon.stars.fill"
        case .working: "bolt.fill"
        case .attention: "eye.fill"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .offline: "bolt.slash.fill"
        }
    }

    private var statusTitle: String {
        switch model.snapshot.activity {
        case .resting: "Resting"
        case .working: "Working"
        case .attention: "Review"
        case .succeeded: "Complete"
        case .failed: "Needs attention"
        case .offline: "Offline"
        }
    }

    private var statusColor: Color {
        switch model.snapshot.activity {
        case .resting: accentColor.opacity(0.72)
        case .working: accentColor
        case .attention: attentionColor
        case .succeeded: .green
        case .failed: errorColor
        case .offline: textColor.opacity(0.45)
        }
    }

    private var connectionColor: Color {
        switch model.snapshot.connectionHealth {
        case .online: accentColor
        case .reconnecting: attentionColor
        case .offline: textColor.opacity(0.45)
        }
    }

    private var connectionTitle: String {
        switch model.snapshot.connectionHealth {
        case .online: "Connected"
        case .reconnecting: "Reconnecting"
        case .offline: "Disconnected"
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var surfaceColor: Color { Color(habitatHex: theme.surfaceHex) }
    private var textColor: Color { Color(habitatHex: theme.textHex) }
    private var accentColor: Color { Color(habitatHex: theme.accentHex) }
    private var attentionColor: Color { Color(habitatHex: theme.attentionHex) }
    private var errorColor: Color { Color(habitatHex: theme.errorHex) }
}

extension Color {
    init(habitatHex: String) {
        let value = habitatHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let number = UInt64(value, radix: 16) ?? 0
        if value.count == 8 {
            self.init(
                red: Double((number >> 24) & 0xff) / 255,
                green: Double((number >> 16) & 0xff) / 255,
                blue: Double((number >> 8) & 0xff) / 255,
                opacity: Double(number & 0xff) / 255
            )
        } else {
            self.init(
                red: Double((number >> 16) & 0xff) / 255,
                green: Double((number >> 8) & 0xff) / 255,
                blue: Double(number & 0xff) / 255
            )
        }
    }
}

private struct WidgetRow<Content: View>: View {
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    init(
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            content
        }
        .frame(height: 26)
    }
}

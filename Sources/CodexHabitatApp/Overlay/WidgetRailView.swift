import HabitatCore
import ResourceKit
import SwiftUI
import WidgetRuntime

enum HabitatWidgetLayoutOrder {
    static func resolve(
        enabled: [WidgetIdentifier],
        themeWidgets: [HabitatWidget]
    ) -> [WidgetIdentifier] {
        let enabledSet = Set(enabled)
        let placed = themeWidgets
            .filter { enabledSet.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.position.y != rhs.position.y {
                    return lhs.position.y < rhs.position.y
                }
                if lhs.position.x != rhs.position.x {
                    return lhs.position.x < rhs.position.x
                }
                return anchorRank(lhs.anchor) < anchorRank(rhs.anchor)
            }
            .map(\.id)
        let placedSet = Set(placed)
        return placed + enabled.filter { !placedSet.contains($0) }
    }

    private static func anchorRank(_ anchor: HabitatAnchor) -> Int {
        switch anchor {
        case .topLeading: 0
        case .topTrailing: 1
        case .center: 2
        case .bottomLeading: 3
        case .bottomTrailing: 4
        }
    }
}

@MainActor
final class WidgetRailModel: ObservableObject {
    @Published private(set) var snapshot: HabitatSnapshot
    @Published private(set) var pomodoroSnapshot: PomodoroSnapshot
    @Published private(set) var countdownSnapshot: CountdownSnapshot

    private var pomodoro: PomodoroTimer
    private var countdown: CountdownTimer
    private var pomodoroTicker: Task<Void, Never>?
    private var countdownTicker: Task<Void, Never>?

    init(
        snapshot: HabitatSnapshot = HabitatSnapshot(),
        configuration: PomodoroConfiguration = PomodoroConfiguration(),
        countdownConfiguration: CountdownConfiguration = CountdownConfiguration(),
        timerClock: any TimerClock = SystemTimerClock()
    ) {
        self.snapshot = snapshot
        do {
            var timer = try PomodoroTimer(configuration: configuration, clock: timerClock)
            pomodoroSnapshot = timer.snapshot()
            pomodoro = timer
            var countdown = try CountdownTimer(
                configuration: countdownConfiguration,
                clock: timerClock
            )
            countdownSnapshot = countdown.snapshot()
            self.countdown = countdown
        } catch {
            preconditionFailure("The built-in timer configurations must be valid")
        }
    }

    deinit {
        pomodoroTicker?.cancel()
        countdownTicker?.cancel()
    }

    func apply(_ snapshot: HabitatSnapshot) {
        self.snapshot = snapshot
    }

    func togglePomodoro() {
        if pomodoroSnapshot.isRunning {
            pomodoro.pause()
            pomodoroTicker?.cancel()
            pomodoroTicker = nil
        } else {
            pomodoro.start()
            beginTicking()
        }
        refreshPomodoro()
    }

    func resetPomodoro() {
        pomodoroTicker?.cancel()
        pomodoroTicker = nil
        pomodoro.reset()
        refreshPomodoro()
    }

    func toggleCountdown() {
        if countdownSnapshot.isRunning {
            countdown.pause()
            countdownTicker?.cancel()
            countdownTicker = nil
        } else {
            countdown.start()
            beginCountdownTicking()
        }
        refreshCountdown()
    }

    func resetCountdown() {
        countdownTicker?.cancel()
        countdownTicker = nil
        countdown.reset()
        refreshCountdown()
    }

    func refreshTimersForTesting() {
        refreshPomodoro()
        refreshCountdown()
    }

    private func beginTicking() {
        pomodoroTicker?.cancel()
        pomodoroTicker = Task { [weak self] in
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

    private func beginCountdownTicking() {
        countdownTicker?.cancel()
        countdownTicker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                refreshCountdown()
                guard countdownSnapshot.isRunning else { return }
            }
        }
    }

    private func refreshCountdown() {
        countdownSnapshot = countdown.snapshot()
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
        Group {
            if Self.requiresScrolling(for: resolvedWidgets) {
                ScrollView(.vertical) { rows }
                    .scrollIndicators(.visible)
            } else {
                rows
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(
            width: HabitatOverlayLayout.widgetRailSize.width,
            height: HabitatOverlayLayout.widgetRailSize.height
        )
        .foregroundStyle(textColor)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(panelColor.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(panelAltColor.opacity(0.06))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(textColor.opacity(0.13), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("Habitat widgets"))
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(resolvedWidgets.enumerated()), id: \.element) { index, id in
                row(for: id)
                if index < resolvedWidgets.count - 1 {
                    Divider()
                        .overlay(textColor.opacity(0.13))
                }
            }
        }
    }

    static func requiresScrolling(for widgets: [WidgetIdentifier]) -> Bool {
        contentHeight(for: widgets) > HabitatOverlayLayout.widgetRailSize.height
    }

    static func contentHeight(for widgets: [WidgetIdentifier]) -> CGFloat {
        guard !widgets.isEmpty else { return 12 }
        let rows = widgets.reduce(CGFloat.zero) { height, widget in
            height + (widget == .pomodoro ? 44 : compactRowHeight)
        }
        return rows + CGFloat(widgets.count - 1) + 12
    }

    fileprivate static let compactRowHeight: CGFloat = 23

    private var resolvedWidgets: [WidgetIdentifier] {
        HabitatWidgetLayoutOrder.resolve(
            enabled: enabledWidgets,
            themeWidgets: theme.widgets
        )
    }

    @ViewBuilder
    private func row(for id: WidgetIdentifier) -> some View {
        switch id {
        case .status:
            statusRow
        case .usage:
            usageRow
        case .tokens:
            tokenRow
        case .context:
            contextRow
        case .speed:
            speedRow
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
            Text(L10n.text(statusTitle))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            if showsConnectionHealth {
                Text(L10n.text(connectionBadgeTitle))
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(connectionColor)
                    .frame(width: 30, alignment: .trailing)
                    .help(L10n.text(connectionTitle))
                Circle()
                    .fill(connectionColor)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel(L10n.text(connectionTitle))
            }
        }
    }

    private var usageRow: some View {
        WidgetRow(systemImage: "gauge.with.dots.needle.50percent", tint: accentColor) {
            if selectedRateLimit?.usedPercent != nil {
                Gauge(value: usagePercent, in: 0...100) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinear)
                .tint(accentColor)
                .accessibilityLabel(L10n.text("Account quota"))
                .accessibilityValue(usageValue)
            } else {
                Text(L10n.text("Quota"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(textColor.opacity(0.62))
                Spacer(minLength: 2)
            }

            Text(usageValue)
                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(textColor.opacity(0.62))
                .frame(minWidth: 32, alignment: .trailing)
        }
    }

    private var tokenRow: some View {
        WidgetRow(systemImage: "number.square.fill", tint: accentColor) {
            Text(L10n.text("Latest request"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(textColor.opacity(0.62))
            Spacer(minLength: 2)
            Text(tokenValue)
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
        }
        .help(taskCumulativeDetail)
        .accessibilityHint(taskCumulativeDetail)
    }

    private var contextRow: some View {
        WidgetRow(systemImage: "chart.bar.fill", tint: attentionColor) {
            Gauge(value: contextPercent, in: 0...100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinear)
            .tint(attentionColor)
            .accessibilityLabel(L10n.text("Context used"))
            .accessibilityValue(contextValue)

            Text(contextValue)
                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(textColor.opacity(0.62))
                .frame(width: 32, alignment: .trailing)
        }
    }

    private var speedRow: some View {
        WidgetRow(systemImage: "clock.arrow.circlepath", tint: .green) {
            Text(L10n.text("Recent 60s output"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(textColor.opacity(0.62))
            Spacer(minLength: 2)
            Text(speedValue)
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
        }
    }

    private var clockRow: some View {
        WidgetRow(systemImage: "clock.fill", tint: attentionColor) {
            HabitatClockText(uses24HourClock: uses24HourClock)
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
                Text(L10n.text(model.pomodoroSnapshot.phase == .rest ? "REST" : "FOCUS"))
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
            Text(formattedDuration(model.countdownSnapshot.remainingSeconds))
                .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(model.countdownSnapshot.isComplete ? errorColor : textColor)
                .accessibilityLabel(L10n.text("Countdown"))
                .accessibilityValue(formattedDuration(model.countdownSnapshot.remainingSeconds))
            Spacer(minLength: 2)
            timerButton(
                systemImage: model.countdownSnapshot.isRunning ? "pause.fill" : "play.fill",
                label: model.countdownSnapshot.isRunning ? "Pause countdown" : "Start countdown",
                identifier: "widgets.countdown.toggle",
                action: model.toggleCountdown
            )
            timerButton(
                systemImage: "arrow.counterclockwise",
                label: "Reset countdown",
                identifier: "widgets.countdown.reset",
                action: model.resetCountdown
            )
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
        .help(L10n.text(label))
        .accessibilityLabel(L10n.text(label))
        .accessibilityIdentifier(identifier)
    }

    private var usagePercent: Double {
        min(max(selectedRateLimit?.usedPercent ?? 0, 0), 100)
    }

    private var usageValue: String {
        guard selectedRateLimit?.usedPercent != nil else {
            return model.snapshot.tokenMetrics == nil ? "--" : "API Key"
        }
        return "\(Int(usagePercent.rounded()))%"
    }

    private var tokenValue: String {
        guard let tokens = model.snapshot.tokenMetrics?.latestRequestTokens else { return "--" }
        return Self.compactCount(tokens)
    }

    private var taskCumulativeDetail: String {
        guard let tokens = model.snapshot.tokenMetrics?.taskCumulativeTokens else {
            return L10n.text("Task cumulative unavailable")
        }
        return L10n.format("Task cumulative: %@ Tokens", Self.compactCount(tokens))
    }

    private var contextPercent: Double {
        min(max(model.snapshot.tokenMetrics?.contextUsedPercent ?? 0, 0), 100)
    }

    private var contextValue: String {
        guard model.snapshot.tokenMetrics?.contextUsedPercent != nil else { return "--" }
        return "\(Int(contextPercent.rounded()))%"
    }

    private var speedValue: String {
        guard let tokens = model.snapshot.tokenMetrics?.recentOutputTokens else { return "--" }
        return L10n.format("%@ / 60s", Self.compactCount(tokens))
    }

    private static func compactCount(_ value: Int) -> String {
        let count = max(0, value)
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private var selectedRateLimit: RateLimitSummary? {
        guard case let .usage(configuration)? = configuration(for: .usage) else {
            return model.snapshot.primaryRateLimit
        }
        return configuration.bucket == .secondary
            ? model.snapshot.secondaryRateLimit
            : model.snapshot.primaryRateLimit
    }

    private var showsConnectionHealth: Bool {
        guard case let .status(configuration)? = configuration(for: .status) else { return true }
        return configuration.showsConnectionHealth
    }

    private var uses24HourClock: Bool {
        guard case let .clock(configuration)? = configuration(for: .clock) else { return false }
        return configuration.uses24HourClock
    }

    private func configuration(for id: WidgetIdentifier) -> HabitatWidgetConfiguration? {
        theme.widgets.first(where: { $0.id == id })?.configuration
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
        case .estimated: attentionColor
        case .reconnecting: attentionColor
        case .offline: textColor.opacity(0.45)
        }
    }

    private var connectionTitle: String {
        switch model.snapshot.connectionHealth {
        case .online: "Connected"
        case .estimated: "Local activity estimate"
        case .reconnecting: "Reconnecting"
        case .offline: "Disconnected"
        }
    }

    private var connectionBadgeTitle: String {
        switch model.snapshot.connectionHealth {
        case .online: "LIVE"
        case .estimated: "EST."
        case .reconnecting: "RETRY"
        case .offline: "OFF"
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var panelColor: Color { Color(habitatHex: theme.panelHex) }
    private var panelAltColor: Color { Color(habitatHex: theme.panelAltHex) }
    private var textColor: Color { Color(habitatHex: theme.textHex) }
    private var accentColor: Color { Color(habitatHex: theme.accentHex) }
    private var attentionColor: Color { Color(habitatHex: theme.attentionHex) }
    private var errorColor: Color { Color(habitatHex: theme.errorHex) }
}

private struct HabitatClockText: View {
    let uses24HourClock: Bool
    @State private var date = Date()

    var body: some View {
        Group {
            if uses24HourClock {
                Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
            } else {
                Text(date, format: .dateTime.hour().minute())
            }
        }
            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .accessibilityLabel(L10n.text("Local time"))
            .task {
                while !Task.isCancelled {
                    let seconds = Calendar.current.component(.second, from: Date())
                    do {
                        try await Task.sleep(for: .seconds(max(1, 60 - seconds)))
                    } catch {
                        return
                    }
                    date = Date()
                }
            }
    }
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
        .frame(height: WidgetRailView.compactRowHeight)
    }
}

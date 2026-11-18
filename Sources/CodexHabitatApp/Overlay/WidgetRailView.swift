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
    let pomodoroConfiguration: PomodoroConfiguration

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
        pomodoroConfiguration = configuration
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                    .scrollIndicators(.hidden)
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
            hudGlassBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            accentColor.opacity(0.36),
                            textColor.opacity(0.11),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.26), radius: 5, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("Habitat widgets"))
    }

    @ViewBuilder
    private var hudGlassBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        ZStack {
            if !reduceTransparency {
                shape.fill(.ultraThinMaterial)
            }
            shape.fill(panelColor.opacity(reduceTransparency ? 0.98 : 0.86))
            shape.fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.13),
                        panelAltColor.opacity(0.08),
                        .clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(resolvedWidgets.enumerated()), id: \.element) { index, id in
                row(for: id)
                if index < resolvedWidgets.count - 1 {
                    Rectangle()
                        .fill(textColor.opacity(0.09))
                        .frame(height: 1)
                        .padding(.leading, 22)
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

    static func recentOutputText(_ tokens: Int?) -> String {
        guard let tokens else { return "--" }
        return compactCount(tokens)
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
        WidgetRow(systemImage: statusSymbol, tint: statusColor, hoverTint: textColor) {
            Text(L10n.text(statusTitle))
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer(minLength: 4)
            if showsConnectionHealth {
                HStack(spacing: 4) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 5.5, height: 5.5)
                        .shadow(color: connectionColor.opacity(0.75), radius: 2.5)
                        .accessibilityLabel(L10n.text(connectionTitle))
                    Text(L10n.text(connectionBadgeTitle))
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(connectionColor)
                }
                .padding(.horizontal, 5.5)
                .padding(.vertical, 2)
                .background(connectionColor.opacity(0.14), in: Capsule())
                .help(L10n.text(connectionTitle))
            }
        }
    }

    private var usageRow: some View {
        WidgetRow(
            systemImage: selectedRateLimit?.usedPercent != nil
                ? "gauge.with.dots.needle.50percent"
                : "sum",
            tint: secondaryColor,
            hoverTint: textColor
        ) {
            if selectedRateLimit?.usedPercent != nil {
                HabitatMiniProgressBar(
                    percent: usagePercent,
                    normalTint: accentColor,
                    secondaryTint: secondaryColor,
                    warningTint: attentionColor,
                    dangerTint: errorColor,
                    trackTint: textColor.opacity(0.12)
                )
                .accessibilityLabel(L10n.text("Account quota"))
                .accessibilityValue(usageValue)

                Text(usageValue)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(textColor.opacity(0.86))
                    .contentTransition(.numericText())
                    .frame(minWidth: 32, alignment: .trailing)
            } else if let cumulative = model.snapshot.tokenMetrics?.taskCumulativeTokens {
                Text(L10n.text("Task cumulative"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(mutedTextColor)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(Self.compactCount(cumulative))
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(textColor.opacity(0.92))
                    .contentTransition(.numericText())
                    .lineLimit(1)
            } else {
                Text(L10n.text("Quota"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(mutedTextColor)
                Spacer(minLength: 2)
                Text(usageValue)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(mutedTextColor)
                    .frame(minWidth: 32, alignment: .trailing)
            }
        }
        .help(usageDetail)
        .accessibilityHint(usageDetail)
    }

    private var tokenRow: some View {
        WidgetRow(systemImage: "sparkles.rectangle.stack.fill", tint: accentColor, hoverTint: textColor) {
            Text(L10n.text("Latest request"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(mutedTextColor)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(tokenValue)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(textColor.opacity(0.95))
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .help(tokenBreakdownDetail)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("Latest request"))
        .accessibilityValue(metricAccessibilityValue(tokenValue))
        .accessibilityHint(taskCumulativeDetail)
    }

    private var contextRow: some View {
        WidgetRow(systemImage: "cpu.fill", tint: attentionColor, hoverTint: textColor) {
            if model.snapshot.tokenMetrics?.contextUsedPercent != nil {
                HabitatMiniProgressBar(
                    percent: contextPercent,
                    normalTint: attentionColor,
                    secondaryTint: accentColor,
                    warningTint: attentionColor,
                    dangerTint: errorColor,
                    trackTint: textColor.opacity(0.12)
                )
                .accessibilityLabel(L10n.text("Context used"))
                .accessibilityValue(contextValue)
            } else {
                Text(L10n.text("Context"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(mutedTextColor)
                Spacer(minLength: 2)
            }

            Text(contextValue)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(
                    model.snapshot.tokenMetrics?.contextUsedPercent == nil
                        ? mutedTextColor
                        : textColor.opacity(0.88)
                )
                .contentTransition(.numericText())
                .frame(width: 32, alignment: .trailing)
        }
    }

    private var speedRow: some View {
        WidgetRow(systemImage: "waveform.path.ecg", tint: .mint, hoverTint: textColor) {
            Text(L10n.text("Recent 60s output"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(mutedTextColor)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(speedValue)
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(speedValue == "--" ? mutedTextColor : .mint)
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("Recent 60s output"))
        .accessibilityValue(metricAccessibilityValue(speedValue))
    }

    private var clockRow: some View {
        WidgetRow(systemImage: "clock.fill", tint: attentionColor, hoverTint: textColor) {
            HabitatClockText(uses24HourClock: uses24HourClock)
            Spacer(minLength: 0)
        }
    }

    private var pomodoroRow: some View {
        let isRest = model.pomodoroSnapshot.phase == .rest
        let phaseTint = isRest ? secondaryColor : errorColor
        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(textColor.opacity(0.12), lineWidth: 2.2)
                Circle()
                    .trim(from: 0, to: pomodoroProgress)
                    .stroke(
                        phaseTint,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Image(systemName: isRest ? "cup.and.saucer.fill" : "flame.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(phaseTint)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.text(isRest ? "REST" : "FOCUS"))
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseTint)
                Text(formattedDuration(model.pomodoroSnapshot.remainingSeconds))
                    .font(.system(size: 13.5, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            timerButton(
                systemImage: model.pomodoroSnapshot.isRunning ? "pause.fill" : "play.fill",
                label: model.pomodoroSnapshot.isRunning ? "Pause focus timer" : "Start focus timer",
                identifier: "widgets.pomodoro.toggle",
                size: 24,
                isProminent: model.pomodoroSnapshot.isRunning,
                tint: phaseTint,
                action: model.togglePomodoro
            )
            timerButton(
                systemImage: "arrow.counterclockwise",
                label: "Reset focus timer",
                identifier: "widgets.pomodoro.reset",
                size: 24,
                isProminent: false,
                tint: textColor,
                action: model.resetPomodoro
            )
        }
        .frame(height: 44)
    }

    private var countdownRow: some View {
        WidgetRow(systemImage: "hourglass", tint: accentColor, hoverTint: textColor) {
            Text(formattedDuration(model.countdownSnapshot.remainingSeconds))
                .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(model.countdownSnapshot.isComplete ? errorColor : textColor)
                .contentTransition(.numericText())
                .accessibilityLabel(L10n.text("Countdown"))
                .accessibilityValue(formattedDuration(model.countdownSnapshot.remainingSeconds))
            Spacer(minLength: 2)
            timerButton(
                systemImage: model.countdownSnapshot.isRunning ? "pause.fill" : "play.fill",
                label: model.countdownSnapshot.isRunning ? "Pause countdown" : "Start countdown",
                identifier: "widgets.countdown.toggle",
                size: 19,
                isProminent: model.countdownSnapshot.isRunning,
                tint: accentColor,
                action: model.toggleCountdown
            )
            timerButton(
                systemImage: "arrow.counterclockwise",
                label: "Reset countdown",
                identifier: "widgets.countdown.reset",
                size: 19,
                isProminent: false,
                tint: textColor,
                action: model.resetCountdown
            )
        }
    }

    private func timerButton(
        systemImage: String,
        label: String,
        identifier: String,
        size: CGFloat,
        isProminent: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size <= 20 ? 9 : 10, weight: .bold))
                .foregroundStyle(isProminent ? tint : textColor.opacity(0.86))
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isProminent ? tint.opacity(0.20) : textColor.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 5.5, style: .continuous)
        )
        .help(L10n.text(label))
        .accessibilityLabel(L10n.text(label))
        .accessibilityIdentifier(identifier)
    }

    private var pomodoroProgress: Double {
        let total = model.pomodoroSnapshot.phase == .rest
            ? model.pomodoroConfiguration.restSeconds
            : model.pomodoroConfiguration.focusSeconds
        guard total > 0 else { return 0 }
        let remaining = Double(min(max(model.pomodoroSnapshot.remainingSeconds, 0), total))
        return remaining / Double(total)
    }

    static func quotaResetText(_ resetAt: Date?, now: Date = Date()) -> String? {
        guard let resetAt, resetAt > now else { return nil }
        let formatter = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: L10n.current.resolvedLanguage)
        formatter.calendar = calendar
        let remaining = resetAt.timeIntervalSince(now)
        formatter.allowedUnits = remaining >= 86_400
            ? [.day, .hour]
            : remaining >= 3_600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .brief
        guard let text = formatter.string(from: now, to: resetAt) else { return nil }
        return L10n.format("Resets in %@", text)
    }

    private var usageDetail: String {
        if selectedRateLimit?.usedPercent != nil {
            let used = L10n.format("Account quota used: %@", usageValue)
            guard let reset = Self.quotaResetText(selectedRateLimit?.resetAt) else {
                return used
            }
            return "\(used) · \(reset)"
        }
        if model.snapshot.tokenMetrics != nil {
            return taskCumulativeDetail
        }
        return L10n.text("Account quota unavailable")
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

    private var tokenBreakdownDetail: String {
        guard let metrics = model.snapshot.tokenMetrics else {
            return taskCumulativeDetail
        }
        let cumulative = L10n.format(
            "Task cumulative: %@ Tokens",
            Self.compactCount(metrics.taskCumulativeTokens)
        )
        let inputPart = Self.compactCount(metrics.inputTokens)
        let outputPart = Self.compactCount(metrics.outputTokens)
        let ioSummary = L10n.format("Input %@ · Output %@", inputPart, outputPart)
        return "\(cumulative) (\(ioSummary))"
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
        Self.recentOutputText(model.snapshot.tokenMetrics?.recentOutputTokens)
    }

    private func metricAccessibilityValue(_ value: String) -> String {
        value == "--" ? L10n.text("Unavailable") : value
    }

    static func compactCount(_ value: Int) -> String {
        let count = max(0, value)
        if count >= 1_000_000_000 {
            return String(format: "%.1fB", Double(count) / 1_000_000_000)
        }
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
        case .resting: accentColor.opacity(0.82)
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
    private var mutedTextColor: Color { Color(habitatHex: theme.mutedTextHex).opacity(0.82) }
    private var accentColor: Color { Color(habitatHex: theme.accentHex) }
    private var secondaryColor: Color { Color(habitatHex: theme.secondaryHex) }
    private var attentionColor: Color { Color(habitatHex: theme.attentionHex) }
    private var errorColor: Color { Color(habitatHex: theme.errorHex) }
}

private struct HabitatMiniProgressBar: View {
    let percent: Double
    let normalTint: Color
    let secondaryTint: Color
    let warningTint: Color
    let dangerTint: Color
    let trackTint: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(percent, 0), 100) / 100
            let fillWidth = max(clamped > 0 ? 5 : 0, proxy.size.width * clamped)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackTint)
                if fillWidth > 0 {
                    Capsule(style: .continuous)
                        .fill(barGradient)
                        .frame(width: fillWidth)
                        .shadow(color: activeTint.opacity(0.45), radius: 2.5)
                }
            }
            .frame(height: 5.5)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 12)
    }

    private var activeTint: Color {
        if percent >= 90 { return dangerTint }
        if percent >= 72 { return warningTint }
        return normalTint
    }

    private var barGradient: LinearGradient {
        if percent >= 90 {
            return LinearGradient(
                colors: [warningTint, dangerTint],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        if percent >= 72 {
            return LinearGradient(
                colors: [normalTint, warningTint],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [normalTint, secondaryTint],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
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
            .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
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
    let hoverTint: Color
    @ViewBuilder let content: Content
    @State private var isHovered = false

    init(
        systemImage: String,
        tint: Color,
        hoverTint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.hoverTint = hoverTint
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 16, height: 16)
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 17)
            content
        }
        .padding(.horizontal, 3)
        .frame(height: WidgetRailView.compactRowHeight)
        .background(
            hoverTint.opacity(isHovered ? 0.06 : 0),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

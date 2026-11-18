import HabitatCore
import PetRuntime
import SwiftUI

struct HabitatSettingsView: View {
    @ObservedObject var model: HabitatAppModel
    @ObservedObject private var bridge = ThemeBridgeIntegrationModel.shared
    @Binding var selectedSection: SettingsSection
    @ObservedObject var desktopController: HabitatDesktopController
    @State private var demoWorkingMode = false
    @State private var stageReaction: PetAnimation?
    @State private var stageReactionTask: Task<Void, Never>?
    @State private var stagePatCounter = 0

    var body: some View {
        SettingsPage(
            "Habitat",
            subtitle: "Desktop placement, interaction, and motion"
        ) {
            VStack(alignment: .leading, spacing: 22) {
                cockpitHeroSection

                telemetryGrid

                overviewBands

                SettingsGroup("Display and motion") {
                    VStack(spacing: 14) {
                        scaleControl

                        Picker(
                            L10n.text("Motion"),
                            selection: Binding(
                                get: { model.settings.reduceMotion },
                                set: { model.setReduceMotion($0) }
                            )
                        ) {
                            Text(L10n.text("System")).tag(ReduceMotionPreference.system)
                            Text(L10n.text("Reduced")).tag(ReduceMotionPreference.reduce)
                            Text(L10n.text("Full")).tag(ReduceMotionPreference.full)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("habitat.motion")
                    }
                    .padding(16)
                    .background(
                        .quaternary.opacity(0.28),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }

                interactionSettings
            }
        }
        .onDisappear {
            stageReactionTask?.cancel()
        }
    }

    private var selectedPetEntry: PetLibraryEntry? {
        model.validPets.first(where: { $0.manifest?.id == model.settings.selectedPetID })
            ?? model.validPets.first
    }

    private var cockpitHeroSection: some View {
        let theme = model.selectedTheme
        let surface = Color(habitatHex: theme.surfaceHex)
        let panel = Color(habitatHex: theme.panelHex)
        let accent = Color(habitatHex: theme.accentHex)
        let secondary = Color(habitatHex: theme.secondaryHex)
        let text = Color(habitatHex: theme.textHex)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(L10n.text("Live Companion Stage"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(text)
                        Text(L10n.text(theme.name))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(accent.opacity(0.16), in: Capsule())
                    }
                    Text(L10n.text("Real-time desktop HUD and animated companion synced with local Codex sessions"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(text.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: triggerStagePat) {
                    Label(L10n.text("Pat Companion"), systemImage: "hand.wave.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(text)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accent.opacity(0.26), in: Capsule())
                .overlay {
                    Capsule().stroke(accent.opacity(0.55), lineWidth: 1)
                }

                Button {
                    demoWorkingMode.toggle()
                } label: {
                    Label(
                        L10n.text(demoWorkingMode ? "Coding Preview" : "Simulate Coding"),
                        systemImage: demoWorkingMode ? "bolt.fill" : "play.circle"
                    )
                    .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(demoWorkingMode ? Color.black : text.opacity(0.88))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    demoWorkingMode ? accent : text.opacity(0.10),
                    in: Capsule()
                )
            }

            HStack(spacing: 18) {
                WidgetRailView(
                    model: desktopController.widgetModel,
                    enabledWidgets: model.settings.widgetOrder.isEmpty
                        ? HabitatSettings.default.widgetOrder
                        : model.settings.widgetOrder,
                    theme: theme
                )

                CockpitLivePetStage(
                    pet: selectedPetEntry,
                    activity: demoWorkingMode
                        ? .working
                        : desktopController.currentSnapshot.activity,
                    requestedAnimation: stageReaction,
                    accentColor: accent,
                    textColor: text,
                    onTap: triggerStagePat
                )
                .frame(width: 140, height: 136)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    if !model.validPets.isEmpty {
                        Text(L10n.text("Quick Companion"))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(text.opacity(0.62))
                        HStack(spacing: 6) {
                            ForEach(model.validPets.prefix(4), id: \.packageURL) { entry in
                                let petID = entry.manifest?.id
                                let isSelected = petID == model.settings.selectedPetID
                                Button {
                                    model.selectPet(petID)
                                } label: {
                                    PetMiniAvatar(pet: entry)
                                        .frame(width: 34, height: 34)
                                        .padding(3)
                                        .background(
                                            isSelected ? accent.opacity(0.24) : text.opacity(0.07),
                                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(
                                                    isSelected ? accent : text.opacity(0.12),
                                                    lineWidth: isSelected ? 1.5 : 1
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                                .help(L10n.text(entry.manifest?.displayName ?? "Pet"))
                            }
                        }
                    }

                    Text(L10n.text("Quick Theme"))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(text.opacity(0.62))
                        .padding(.top, 2)

                    HStack(spacing: 6) {
                        ForEach(featuredThemes, id: \.id) { candidate in
                            let isSelected = candidate.id == model.selectedTheme.id
                            Button {
                                model.selectTheme(candidate.id)
                            } label: {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(habitatHex: candidate.accentHex),
                                                Color(habitatHex: candidate.surfaceHex),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        Circle()
                                            .stroke(
                                                isSelected ? Color.white : text.opacity(0.22),
                                                lineWidth: isSelected ? 2 : 1
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(L10n.text(candidate.name))
                        }
                    }
                }
            }
        }
        .padding(18)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [surface, panel],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RadialGradient(
                    colors: [accent.opacity(0.22), secondary.opacity(0.08), .clear],
                    center: .topLeading,
                    startRadius: 12,
                    endRadius: 340
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.50), text.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    private var featuredThemes: [HabitatThemeDescriptor] {
        let spotlightIDs = [
            "workbench",
            "arcade-signal",
            "cyber-cafe",
            "nebula-vanguard",
            "spirit-lantern-town",
            "quiet-garden",
        ]
        return spotlightIDs.compactMap { id in
            model.availableThemes.first(where: { $0.id == id })
        }
    }

    private var telemetryGrid: some View {
        let metrics = desktopController.currentSnapshot.tokenMetrics
        let pomodoro = desktopController.widgetModel.pomodoroSnapshot
        let accent = Color(habitatHex: model.selectedTheme.accentHex)

        return LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 150), spacing: 10),
                GridItem(.flexible(minimum: 150), spacing: 10),
                GridItem(.flexible(minimum: 150), spacing: 10),
                GridItem(.flexible(minimum: 150), spacing: 10),
            ],
            spacing: 10
        ) {
            telemetryCard(
                title: L10n.text("Latest request"),
                symbol: "sparkles.rectangle.stack.fill",
                tint: accent,
                value: metrics?.latestRequestTokens.map(WidgetRailView.compactCount) ?? "--",
                detail: metrics.map {
                    L10n.format(
                        "Input %@ · Output %@",
                        WidgetRailView.compactCount($0.lastInputTokens ?? 0),
                        WidgetRailView.compactCount($0.lastOutputTokens ?? 0)
                    )
                } ?? L10n.text("Waiting for Codex session")
            )

            telemetryCard(
                title: L10n.text("Context used"),
                symbol: "cpu.fill",
                tint: .orange,
                value: metrics?.contextUsedPercent.map { "\(Int($0.rounded()))%" } ?? "--",
                detail: metrics?.modelContextWindow.map {
                    L10n.format("Window %@", WidgetRailView.compactCount($0))
                } ?? L10n.text("Sanitized session window")
            )

            telemetryCard(
                title: L10n.text("Task cumulative"),
                symbol: "sum",
                tint: .mint,
                value: metrics.map { WidgetRailView.compactCount($0.taskCumulativeTokens) } ?? "--",
                detail: metrics.map {
                    L10n.format("Cached %@", WidgetRailView.compactCount($0.cachedInputTokens))
                } ?? L10n.text("Local JSONL telemetry")
            )

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        L10n.text(pomodoro.phase == .rest ? "Rest" : "Pomodoro"),
                        systemImage: pomodoro.phase == .rest ? "cup.and.saucer.fill" : "flame.fill"
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.pink)
                    .lineLimit(1)

                    Text(String(
                        format: "%02d:%02d",
                        pomodoro.remainingSeconds / 60,
                        pomodoro.remainingSeconds % 60
                    ))
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)

                    Text(L10n.text(pomodoro.isRunning ? "Timer active" : "Ready to focus"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(spacing: 5) {
                    Button(action: desktopController.widgetModel.togglePomodoro) {
                        Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .controlSize(.small)
                    .help(L10n.text(pomodoro.isRunning ? "Pause focus timer" : "Start focus timer"))

                    Button(action: desktopController.widgetModel.resetPomodoro) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 26, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help(L10n.text("Reset focus timer"))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .quaternary.opacity(0.28),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func telemetryCard(
        title: String,
        symbol: String,
        tint: Color,
        value: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .quaternary.opacity(0.28),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func triggerStagePat() {
        desktopController.patPet()
        stageReactionTask?.cancel()
        stagePatCounter &+= 1
        stageReaction = stagePatCounter.isMultiple(of: 2) ? .jumping : .waving
        stageReactionTask = Task {
            try? await Task.sleep(for: .milliseconds(1_350))
            guard !Task.isCancelled else { return }
            stageReaction = nil
        }
    }

    private var overviewState: HabitatOverviewState {
        let rawPetName = model.validPets.first {
            $0.manifest?.id == model.settings.selectedPetID
        }?.manifest?.displayName
        let petName = rawPetName.map(L10n.text)
        return HabitatOverviewState(
            isHabitatVisible: model.isHabitatVisible,
            selectedPetName: petName,
            positionLocked: model.settings.positionLocked,
            enabledWidgetCount: model.settings.widgetOrder.count,
            snapshot: desktopController.currentSnapshot,
            selectedThemeName: model.selectedTheme.name,
            themeSupportsCodexBridge: model.selectedThemeSupportsCodexBridge,
            themeBridgeState: bridge.state,
            canRestoreOfficialAppearance: bridge.canRestore
        )
    }

    private var overviewBands: some View {
        VStack(spacing: 0) {
            ForEach(Array(overviewState.sections.enumerated()), id: \.element.id) { index, section in
                overviewRow(section)
                    .padding(.horizontal, 14)
                if index < overviewState.sections.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background(
            .quaternary.opacity(0.28),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityIdentifier("habitat.overview")
    }

    private func overviewRow(_ section: HabitatOverviewState.Section) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                overviewSummary(section)
                Spacer(minLength: 12)
                overviewActions(section)
            }
            VStack(alignment: .leading, spacing: 10) {
                overviewSummary(section)
                overviewActions(section)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityIdentifier("habitat.overview.\(section.kind.rawValue)")
    }

    private func overviewSummary(_ section: HabitatOverviewState.Section) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.13))
                    .frame(width: 32, height: 32)
                Image(systemName: section.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(L10n.text(section.title))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(section.primaryContent.localized)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    ForEach(Array(section.factContents.enumerated()), id: \.offset) { index, fact in
                        if index > 0 {
                            Text("·")
                                .foregroundStyle(.tertiary)
                        }
                        Text(fact.localized)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func overviewActions(_ section: HabitatOverviewState.Section) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(section.actions.enumerated()), id: \.offset) { _, action in
                overviewAction(action)
            }
        }
    }

    @ViewBuilder
    private func overviewAction(_ action: HabitatOverviewState.Action) -> some View {
        switch action {
        case let .setHabitatVisibility(isVisible):
            Button {
                perform(action)
            } label: {
                Label(
                    action.content.localized,
                    systemImage: isVisible ? "eye" : "eye.slash"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityIdentifier("habitat.overview.visibility")
        case let .setPositionLocked(isLocked):
            Button {
                perform(action)
            } label: {
                Label(
                    action.content.localized,
                    systemImage: isLocked ? "lock" : "lock.open"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("habitat.overview.position-lock")
        case .navigate:
            Button {
                perform(action)
            } label: {
                HStack(spacing: 4) {
                    Text(action.content.localized)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private func perform(_ action: HabitatOverviewState.Action) {
        switch action {
        case let .setHabitatVisibility(isVisible):
            model.isHabitatVisible = isVisible
        case let .setPositionLocked(isLocked):
            model.setPositionLocked(isLocked)
        case let .navigate(section):
            selectedSection = section
        }
    }

    private var scaleControl: some View {
        HStack(spacing: 12) {
            Label(L10n.text("Scale"), systemImage: "arrow.up.left.and.arrow.down.right")
                .frame(width: 110, alignment: .leading)
            Slider(
                value: Binding(
                    get: { model.settings.scale },
                    set: { model.setScale($0) }
                ),
                in: 0.75...1.5,
                step: 0.05
            )
            .accessibilityIdentifier("habitat.scale")
            .accessibilityLabel(L10n.text("Scale"))
            .accessibilityValue(scaleAccessibilityValue)
            Text(model.settings.scale, format: .percent.precision(.fractionLength(0)))
                .font(.system(.body, design: .monospaced))
                .frame(width: 42, alignment: .trailing)
            Button(action: { model.setScale(1) }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help(L10n.text("Reset scale"))
            .accessibilityLabel(L10n.text("Reset scale"))
            .accessibilityIdentifier("habitat.scale.reset")
        }
    }

    private var scaleAccessibilityValue: String {
        model.settings.scale.formatted(.percent.precision(.fractionLength(0)))
    }

    private var interactionSettings: some View {
        SettingsGroup("Interaction") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(
                    L10n.text("Click through the overlay"),
                    isOn: Binding(
                        get: { model.settings.clickThrough },
                        set: { model.setClickThrough($0) }
                    )
                )
                .accessibilityIdentifier("habitat.click-through")

                Toggle(
                    L10n.text("Lock overlay position"),
                    isOn: Binding(
                        get: { model.settings.positionLocked },
                        set: { model.setPositionLocked($0) }
                    )
                )
                .disabled(model.settings.clickThrough)
                .accessibilityIdentifier("habitat.position-locked")

                Toggle(
                    L10n.text("Open Codex Habitat at login"),
                    isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .accessibilityIdentifier("habitat.launch-at-login")

                if model.launchAtLoginStatus == .requiresApproval {
                    HStack(spacing: 12) {
                        Label(L10n.text("Approval required in Login Items"), systemImage: "person.badge.key.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button(L10n.text("Open Settings"), action: model.openLoginItemSettings)
                            .controlSize(.small)
                    }
                } else if model.launchAtLoginStatus == .unavailable {
                    Label(L10n.text("Login item unavailable for this app location"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = model.errorMessage {
                    Label(L10n.text(errorMessage), systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .quaternary.opacity(0.28),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
    }
}

private struct CockpitLivePetStage: View {
    let pet: PetLibraryEntry?
    let activity: AgentActivity
    let requestedAnimation: PetAnimation?
    let accentColor: Color
    let textColor: Color
    let onTap: () -> Void
    @State private var renderer: SpriteSheetRenderer?
    @State private var availableRows: Set<Int> = Set(0..<9)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(textColor.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(accentColor.opacity(0.24), lineWidth: 1)
                    }

                RadialGradient(
                    colors: [accentColor.opacity(0.28), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: 62
                )

                if let renderer {
                    PetSpriteView(
                        activity: activity,
                        requestedAnimation: requestedAnimation,
                        renderer: renderer,
                        renderMode: .pixelated,
                        pixelArtHint: true,
                        clock: SystemAnimationClock(),
                        availableRows: availableRows,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: 122, height: 126)
                    .offset(y: -4)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let name = pet?.manifest?.displayName {
                    Text(L10n.text(name))
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(textColor.opacity(0.88))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.35), in: Capsule())
                        .padding(.bottom, 5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(L10n.text("Pat Companion"))
        .task(id: pet?.packageURL) {
            guard let pet, let url = pet.spritesheetURL, let atlas = pet.atlas else {
                renderer = nil
                return
            }
            let loaded = await Task.detached(priority: .userInitiated) {
                SpriteSheetRenderer(contentsOf: url, atlas: atlas)
            }.value
            guard !Task.isCancelled else { return }
            renderer = loaded.isRenderable ? loaded : nil
            availableRows = Set(0..<min(atlas.rows, 9))
        }
    }
}

private struct PetMiniAvatar: View {
    let pet: PetLibraryEntry
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: pet.packageURL) {
            image = await PetThumbnailStore.shared.image(for: pet)
        }
    }
}

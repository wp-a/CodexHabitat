import HabitatCore
import SwiftUI

struct HabitatSettingsView: View {
    @ObservedObject var model: HabitatAppModel
    @ObservedObject private var bridge = ThemeBridgeIntegrationModel.shared
    @Binding var selectedSection: SettingsSection
    @ObservedObject var desktopController: HabitatDesktopController

    var body: some View {
        SettingsPage(
            "Habitat",
            subtitle: "Desktop placement, interaction, and motion"
        ) {
            VStack(alignment: .leading, spacing: 0) {
                overviewBands

                SettingsGroup("Display and motion") {
                    scaleControl

                    Picker(
                        "Motion",
                        selection: Binding(
                            get: { model.settings.reduceMotion },
                            set: { model.setReduceMotion($0) }
                        )
                    ) {
                        Text("System").tag(ReduceMotionPreference.system)
                        Text("Reduced").tag(ReduceMotionPreference.reduce)
                        Text("Full").tag(ReduceMotionPreference.full)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("habitat.motion")
                }
                .padding(.top, 24)

                Divider()
                    .padding(.vertical, 24)

                interactionSettings
            }
        }
    }

    private var overviewState: HabitatOverviewState {
        let petName = model.validPets.first {
            $0.manifest?.id == model.settings.selectedPetID
        }?.manifest?.displayName
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
            Divider()
            ForEach(Array(overviewState.sections.enumerated()), id: \.element.id) { index, section in
                overviewRow(section)
                if index < overviewState.sections.count - 1 {
                    Divider()
                }
            }
            Divider()
        }
        .accessibilityIdentifier("habitat.overview")
    }

    private func overviewRow(_ section: HabitatOverviewState.Section) -> some View {
        HStack(spacing: 14) {
            Image(systemName: section.systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(L10n.text(section.title))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(section.primaryContent.localized)
                        .font(.system(size: 15, weight: .semibold))
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

            Spacer(minLength: 12)
            overviewAction(section.action)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityIdentifier("habitat.overview.\(section.kind.rawValue)")
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
            .accessibilityIdentifier("habitat.overview.visibility")
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
        case let .navigate(section):
            selectedSection = section
        }
    }

    private var scaleControl: some View {
        HStack(spacing: 12) {
            Label("Scale", systemImage: "arrow.up.left.and.arrow.down.right")
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
            Text(model.settings.scale, format: .percent.precision(.fractionLength(0)))
                .font(.system(.body, design: .monospaced))
                .frame(width: 42, alignment: .trailing)
            Button(action: { model.setScale(1) }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Reset scale")
            .accessibilityLabel("Reset scale")
            .accessibilityIdentifier("habitat.scale.reset")
        }
    }

    private var interactionSettings: some View {
        SettingsGroup("Interaction") {
            Toggle(
                "Click through the overlay",
                isOn: Binding(
                    get: { model.settings.clickThrough },
                    set: { model.setClickThrough($0) }
                )
            )
            .accessibilityIdentifier("habitat.click-through")

            Toggle(
                "Lock overlay position",
                isOn: Binding(
                    get: { model.settings.positionLocked },
                    set: { model.setPositionLocked($0) }
                )
            )
            .disabled(model.settings.clickThrough)
            .accessibilityIdentifier("habitat.position-locked")

            Toggle(
                "Open Codex Habitat at login",
                isOn: Binding(
                    get: { model.settings.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .accessibilityIdentifier("habitat.launch-at-login")

            if model.launchAtLoginStatus == .requiresApproval {
                HStack(spacing: 12) {
                    Label("Approval required in Login Items", systemImage: "person.badge.key.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Open Settings", action: model.openLoginItemSettings)
                        .controlSize(.small)
                }
            } else if model.launchAtLoginStatus == .unavailable {
                Label("Login item unavailable for this app location", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = model.errorMessage {
                Label(L10n.text(errorMessage), systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

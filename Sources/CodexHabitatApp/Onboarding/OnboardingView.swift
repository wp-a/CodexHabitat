import HabitatCore
import SwiftUI
import WidgetRuntime

struct OnboardingView: View {
    @ObservedObject var model: HabitatAppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            footer
        }
        .frame(width: 760, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 42, height: 42)
                .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Habitat")
                    .font(.system(size: 22, weight: .semibold))
                Text(L10n.text(stepTitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(L10n.format("Step %d of 3", model.onboardingStep.rawValue + 1).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(model.onboardingStep.rawValue + 1), total: 3)
                    .frame(width: 116)
                    .accessibilityLabel(L10n.text("Setup progress"))
                    .accessibilityValue(L10n.format("Step %d of 3", model.onboardingStep.rawValue + 1))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.onboardingStep {
        case .habitat:
            habitatStep
        case .pet:
            petStep
        case .widgets:
            widgetsStep
        }
    }

    private var habitatStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepHeading(
                    "Choose a Habitat",
                    detail: "Workbench is a restrained native default. You can switch at any time."
                )
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(HabitatThemeDescriptor.builtIn) { theme in
                        ThemeChoiceCard(
                            theme: theme,
                            isSelected: model.settings.selectedThemeID == theme.id,
                            action: { model.selectTheme(theme.id) }
                        )
                    }
                }
            }
            .padding(24)
        }
    }

    private var petStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    stepHeading(
                        "Choose a Pet",
                        detail: "Valid pets already installed for Codex appear automatically."
                    )
                    Spacer()
                    Button(action: model.refreshPets) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh pets")
                    .accessibilityLabel("Refresh pets")
                    .accessibilityIdentifier("onboarding.pets.refresh")
                }

                if model.validPets.isEmpty {
                    ContentUnavailableView(
                        "No Valid Pets Found",
                        systemImage: "pawprint",
                        description: Text("You can finish setup and add a local pet later.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 142, maximum: 180), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(model.validPets, id: \.packageURL) { pet in
                            PetChoiceCard(
                                pet: pet,
                                isSelected: model.settings.selectedPetID == pet.manifest?.id,
                                action: { model.selectPet(pet.manifest?.id) }
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var widgetsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepHeading(
                    "Choose Widgets",
                    detail: "Keep the desktop rail focused on the metrics and timers you use."
                )

                VStack(spacing: 0) {
                    ForEach(Array(WidgetRegistry.builtIn.descriptors.enumerated()), id: \.element.id) { index, widget in
                        Toggle(
                            isOn: Binding(
                                get: { model.settings.widgetOrder.contains(widget.id) },
                                set: { model.setWidget(widget.id, enabled: $0) }
                            )
                        ) {
                            Label(L10n.text(widget.displayName), systemImage: widget.systemImage)
                                .font(.body.weight(.medium))
                        }
                        .toggleStyle(.switch)
                        .padding(.vertical, 10)
                        .accessibilityIdentifier("onboarding.widgets.\(widget.id.rawValue)")
                        if index < WidgetRegistry.builtIn.descriptors.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var footer: some View {
        HStack {
            Label("Local setup · no account", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if model.onboardingStep != .habitat {
                Button(action: model.moveBackOnboarding) {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityIdentifier("onboarding.back")
            }

            Button(action: advance) {
                Label(
                    L10n.text(model.onboardingStep == .widgets ? "Place Habitat" : "Continue"),
                    systemImage: model.onboardingStep == .widgets ? "checkmark" : "chevron.right"
                )
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("onboarding.continue")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var stepTitle: String {
        switch model.onboardingStep {
        case .habitat: "Habitat appearance"
        case .pet: "Local companion"
        case .widgets: "Desktop widgets"
        }
    }

    private func stepHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text(title))
                .font(.system(size: 20, weight: .semibold))
            Text(L10n.text(detail))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func advance() {
        Task {
            _ = await model.advanceOnboarding()
        }
    }
}

import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var model: HabitatAppModel
    @State private var navigation: SettingsNavigationState
    let visualQAOptions: HabitatVisualQALaunchOptions

    init(
        model: HabitatAppModel,
        visualQAOptions: HabitatVisualQALaunchOptions = .current
    ) {
        self.model = model
        _navigation = State(initialValue: SettingsNavigationState(model: model))
        self.visualQAOptions = visualQAOptions
    }

    var body: some View {
        Group {
            if !model.isLoaded {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 760, height: 520)
                    .accessibilityLabel(L10n.text("Loading Codex Habitat"))
            } else if model.requiresOnboarding {
                OnboardingView(model: model)
            } else {
                settingsNavigation
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .background {
            HabitatSurface(role: .content)
        }
        .habitatDesignEnvironment(
            accentHex: model.selectedTheme.accentHex,
            secondaryHex: model.selectedTheme.secondaryHex
        )
        .task {
            await model.load()
        }
    }

    private var settingsNavigation: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $navigation.selectedSection) { section in
                Label(L10n.text(section.title), systemImage: section.systemImage)
                    .tag(section)
                    .accessibilityIdentifier("settings.sidebar.\(section.rawValue)")
            }
            .navigationTitle("Codex Habitat")
            .navigationSplitViewColumnWidth(min: 152, ideal: 168, max: 190)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailView: some View {
        switch navigation.selectedSection {
        case .habitat:
            HabitatSettingsView(model: model)
        case .pets:
            PetsSettingsView(model: model)
        case .widgets:
            WidgetsSettingsView(model: model)
        case .themes:
            ThemesSettingsView(model: model, visualQAOptions: visualQAOptions)
        case .integrations:
            IntegrationsSettingsView(model: model)
        case .privacy:
            PrivacySettingsView(model: model)
        }
    }
}

struct SettingsNavigationState: Equatable {
    var selectedSection: SettingsSection

    @MainActor
    init(model: HabitatAppModel) {
        selectedSection = model.selectedSettingsSection
    }
}

struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(
        _ title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text(title))
                        .font(.system(size: 24, weight: .semibold))
                    Text(L10n.text(subtitle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.clear)
        .navigationTitle(L10n.text(title))
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text(title).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

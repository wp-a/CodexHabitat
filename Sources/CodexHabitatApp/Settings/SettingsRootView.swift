import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var model: HabitatAppModel
    @ObservedObject private var desktopController: HabitatDesktopController
    @State private var navigation: SettingsNavigationState
    let visualQAOptions: HabitatVisualQALaunchOptions

    init(
        model: HabitatAppModel,
        desktopController: HabitatDesktopController? = nil,
        visualQAOptions: HabitatVisualQALaunchOptions = .current
    ) {
        self.model = model
        _desktopController = ObservedObject(
            wrappedValue: desktopController ?? HabitatDesktopController()
        )
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
        .preferredColorScheme(visualQAColorScheme)
        .task {
            await model.load()
        }
    }

    private var visualQAColorScheme: ColorScheme? {
        switch visualQAOptions.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var settingsNavigation: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $navigation.selectedSection) { section in
                Label(L10n.text(section.title), systemImage: section.systemImage)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    .tag(section)
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 10))
                    .accessibilityIdentifier("settings.sidebar.\(section.rawValue)")
            }
            .navigationTitle(L10n.text("Codex Habitat"))
            .navigationSplitViewColumnWidth(min: 184, ideal: 196, max: 208)
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
            HabitatSettingsView(
                model: model,
                selectedSection: $navigation.selectedSection,
                desktopController: desktopController
            )
        case .pets:
            makePetsSettingsView()
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

    @MainActor
    func makePetsSettingsView() -> PetsSettingsView {
        PetsSettingsView(
            model: model,
            desktopController: desktopController
        )
    }
}

struct SettingsNavigationState: Equatable {
    var selectedSection: SettingsSection

    @MainActor
    init(model: HabitatAppModel) {
        selectedSection = model.selectedSettingsSection
    }
}

enum SettingsPageScrollBehavior {
    case automatic
    case pageOwned
}

struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    let scrollBehavior: SettingsPageScrollBehavior
    @ViewBuilder let content: Content

    init(
        _ title: String,
        subtitle: String,
        scrollBehavior: SettingsPageScrollBehavior = .automatic,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrollBehavior = scrollBehavior
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text(title))
                    .font(.system(size: 21, weight: .semibold))
                Text(L10n.text(subtitle))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)

            Divider()

            workArea
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private var workArea: some View {
        switch scrollBehavior {
        case .automatic:
            ScrollView {
                content
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .pageOwned:
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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
            Text(L10n.text(title))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

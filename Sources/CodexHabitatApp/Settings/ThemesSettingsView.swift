import SwiftUI

struct ThemesSettingsView: View {
    @ObservedObject var model: HabitatAppModel
    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 12)]

    var body: some View {
        SettingsPage(
            "Themes",
            subtitle: "Native Habitat palettes independent from Codex theming"
        ) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(HabitatThemeDescriptor.builtIn) { theme in
                    ThemeChoiceCard(
                        theme: theme,
                        isSelected: model.settings.selectedThemeID == theme.id,
                        action: { model.selectTheme(theme.id) }
                    )
                }
            }
        }
    }
}

struct ThemeChoiceCard: View {
    let theme: HabitatThemeDescriptor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                if let previewURL = theme.previewURL,
                   let image = NSImage(contentsOf: previewURL) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 82)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                HStack {
                    Image(systemName: theme.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette[0])
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(color)
                                .frame(width: 13, height: 13)
                        }
                    }
                }
                Text(theme.name)
                    .font(.body.weight(.semibold))
                Text(theme.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 204, alignment: .topLeading)
            .background(
                isSelected ? palette[0].opacity(0.09) : Color.primary.opacity(0.03),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? palette[0] : Color.primary.opacity(0.09), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("themes.choice.\(theme.id)")
    }

    private var palette: [Color] {
        [
            Color(habitatHex: theme.accentHex),
            Color(habitatHex: theme.attentionHex),
            Color(habitatHex: theme.errorHex),
        ]
    }
}

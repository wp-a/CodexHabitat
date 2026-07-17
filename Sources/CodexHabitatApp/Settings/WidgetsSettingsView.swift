import HabitatCore
import SwiftUI
import WidgetRuntime

struct WidgetsSettingsView: View {
    @ObservedObject var model: HabitatAppModel

    var body: some View {
        SettingsPage(
            "Widgets",
            subtitle: "Compact, local modules shown beside the pet"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(WidgetRegistry.builtIn.descriptors.enumerated()), id: \.element.id) { index, descriptor in
                    widgetRow(descriptor)
                    if index < WidgetRegistry.builtIn.descriptors.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func widgetRow(_ descriptor: WidgetDescriptor) -> some View {
        Toggle(
            isOn: Binding(
                get: { model.settings.widgetOrder.contains(descriptor.id) },
                set: { model.setWidget(descriptor.id, enabled: $0) }
            )
        ) {
            HStack(spacing: 12) {
                Image(systemName: descriptor.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint(for: descriptor.id))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.displayName)
                        .font(.body.weight(.medium))
                    Text(detail(for: descriptor.id))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 11)
        .accessibilityIdentifier("widgets.toggle.\(descriptor.id.rawValue)")
    }

    private func detail(for id: WidgetIdentifier) -> String {
        switch id {
        case .status: "Current Codex activity and connection"
        case .tokens: "Current session Token total"
        case .context: "Current context-window utilization"
        case .speed: "Recent output Tokens per minute"
        case .usage: "Five-hour or weekly account quota when available"
        case .clock: "Local system time"
        case .pomodoro: "Focus and rest timer"
        case .countdown: "Simple local countdown"
        }
    }

    private func tint(for id: WidgetIdentifier) -> Color {
        switch id {
        case .status: .cyan
        case .tokens: .blue
        case .context: .purple
        case .speed: .green
        case .usage: .mint
        case .clock: .orange
        case .pomodoro: .pink
        case .countdown: .indigo
        }
    }
}

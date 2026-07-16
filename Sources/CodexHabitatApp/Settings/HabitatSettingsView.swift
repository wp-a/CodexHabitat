import HabitatCore
import SwiftUI

struct HabitatSettingsView: View {
    @ObservedObject var model: HabitatAppModel

    var body: some View {
        SettingsPage(
            "Habitat",
            subtitle: "Desktop placement, interaction, and motion"
        ) {
            SettingsGroup("Appearance") {
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

            Divider()

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
                    "Open Codex Habitat at login",
                    isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .accessibilityIdentifier("habitat.launch-at-login")
            }
        }
    }
}

import SwiftUI

@main
struct CodexHabitatApp: App {
    var body: some Scene {
        MenuBarExtra("Codex Habitat", systemImage: "sparkles") {
            Text("Codex Habitat")
        }

        Settings {
            Text("Codex Habitat")
                .frame(width: 480, height: 320)
        }
    }
}

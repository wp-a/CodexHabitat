import SwiftUI

struct CodexHabitatGUI: App {
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

@main
enum CodexHabitatEntryPoint {
    @MainActor
    static func main() async {
        if CommandLine.arguments.contains("--doctor-codex") {
            let status = await CodexDoctor.run()
            exit(status)
        }
        CodexHabitatGUI.main()
    }
}

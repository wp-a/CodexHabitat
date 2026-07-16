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
        if CommandLine.arguments.contains("--doctor-pets") {
            let status = PetDoctor.run()
            exit(status)
        }
        if CommandLine.arguments.contains("--preview-overlay") {
            OverlayPreview.run()
            return
        }
        if let previewPetIndex = CommandLine.arguments.firstIndex(of: "--preview-pet"),
           CommandLine.arguments.indices.contains(previewPetIndex + 1) {
            let status = PetPreview.run(id: CommandLine.arguments[previewPetIndex + 1])
            exit(status)
        }
        CodexHabitatGUI.main()
    }
}

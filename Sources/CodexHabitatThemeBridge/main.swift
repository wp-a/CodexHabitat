import Foundation

@main
enum CodexHabitatThemeBridge {
    static func main() {
        if CommandLine.arguments.dropFirst() == ["--version"] {
            print("Codex Habitat Theme Bridge 0.1.0-dev")
        }
    }
}

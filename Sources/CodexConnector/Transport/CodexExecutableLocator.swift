import Foundation

enum CodexExecutableLocator {
    static func locate(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        applicationCandidates: [URL]? = nil,
        standaloneCandidates: [URL]? = nil
    ) -> URL? {
        let applications = applicationCandidates ?? [
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
            URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources/codex"),
        ]
        let standalone = standaloneCandidates ?? [
            homeDirectory.appending(path: ".codex/packages/standalone/current/codex"),
            homeDirectory.appending(path: ".codex/bin/codex"),
        ]
        var candidates: [URL] = []
        if let explicit = environment["CODEX_EXECUTABLE"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !explicit.isEmpty {
            candidates.append(URL(fileURLWithPath: explicit))
        }
        candidates.append(contentsOf: applications)
        candidates.append(contentsOf: standalone)
        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                URL(fileURLWithPath: String($0), isDirectory: true).appending(path: "codex")
            })
        }
        return candidates.first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}

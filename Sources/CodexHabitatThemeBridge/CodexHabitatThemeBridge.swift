import Foundation

@main
enum CodexHabitatThemeBridge {
    static func main() {
        if CommandLine.arguments.dropFirst() == ["--version"] {
            print("Codex Habitat Theme Bridge 0.1.0-dev")
            return
        }
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsage()
            return
        }
        do {
            switch command {
            case "verify":
                let bundleURL = try resolveBundle(path: arguments.dropFirst().first)
                let verified = try CodexBundleVerifier().verify(bundleURL)
                print("verified: \(verified.bundleIdentifier)")
                print("team: \(verified.teamIdentifier)")
                print("version: \(verified.version)")
                print("architecture: \(CodexArchitecture.current.rawValue)")
                print("path: \(verified.bundleURL.path)")
            case "start":
                let authorized = arguments.contains("--authorized")
                let path = arguments.dropFirst().first { $0 != "--authorized" }
                let bundleURL = try resolveBundle(path: path)
                let record = try liveSession().start(
                    bundleURL: bundleURL,
                    authorized: authorized
                )
                print("started: pid=\(record.process.pid) port=\(record.port)")
            case "status":
                switch liveSession().status() {
                case .inactive: print("inactive")
                case .stale: print("stale")
                case let .active(record):
                    print("active: pid=\(record.process.pid) port=\(record.port)")
                }
            case "stop":
                try liveSession().stop()
                print("stopped")
            default:
                printUsage()
                Foundation.exit(64)
            }
        } catch {
            print("theme-bridge: \(String(describing: error))")
            Foundation.exit(1)
        }
    }

    private static func liveSession() -> ThemeSession {
        ThemeSession(
            verifier: CodexBundleVerifier(),
            launcher: LiveThemeProcessLauncher(),
            processInspector: CodexProcessInspector(),
            signaler: LiveThemeProcessSignaler(),
            portAllocator: LiveLoopbackPortAllocator(),
            recordStore: SessionRecordStore(root: sessionRoot()),
            ownerPID: ProcessInfo.processInfo.processIdentifier
        )
    }

    private static func sessionRoot(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let configured = environment["CODEX_HABITAT_HOME"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
                .appending(path: "ThemeBridge", directoryHint: .isDirectory)
        }
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return applicationSupport
            .appending(path: "Codex Habitat", directoryHint: .isDirectory)
            .appending(path: "ThemeBridge", directoryHint: .isDirectory)
    }

    private static func resolveBundle(path: String?) throws -> URL {
        if let path {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        let roots = CodexBundleVerifier.defaultBundleRoots()
        let names = ["ChatGPT.app", "Codex.app"]
        for root in roots {
            for name in names {
                let candidate = root.appending(path: name, directoryHint: .isDirectory)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        throw CodexBundleVerificationError.inspectionFailed
    }

    private static func printUsage() {
        print("usage: CodexHabitatThemeBridge verify [app] | start --authorized [app] | status | stop")
    }
}

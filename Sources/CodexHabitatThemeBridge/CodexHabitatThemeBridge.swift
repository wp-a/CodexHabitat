import Darwin
import Foundation

@main
enum CodexHabitatThemeBridge {
    static func main() async {
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
            case "apply":
                guard let themeID = value(after: "--theme", in: arguments) else {
                    throw ThemeBridgeCLIError.invalidTheme
                }
                let theme = try BridgeThemeResolver().resolve(id: themeID)
                let bundleURL = try resolveBundle(
                    path: value(after: "--app", in: arguments)
                )
                let screenshotURL = value(after: "--screenshot", in: arguments).map {
                    URL(fileURLWithPath: $0)
                }
                let session = liveSession()
                let result = try await liveCoordinator(session: session).apply(
                    bundleURL: bundleURL,
                    theme: theme,
                    authorized: arguments.contains("--authorized"),
                    screenshotURL: screenshotURL
                )
                print("applied: theme=\(themeID) targets=\(result.targetCount) health=pass")
            case "restore":
                let bundleURL = try resolveBundle(
                    path: value(after: "--app", in: arguments)
                )
                let session = liveSession()
                try await liveCoordinator(session: session).restore(bundleURL: bundleURL)
                print("restored")
            case "watch":
                guard let themeID = value(after: "--theme", in: arguments),
                      let parentValue = value(after: "--parent-pid", in: arguments),
                      let parentPID = Int32(parentValue),
                      parentPID > 1,
                      parentPID == getppid()
                else {
                    throw ThemeBridgeCLIError.invalidParentProcess
                }
                let theme = try BridgeThemeResolver().resolve(id: themeID)
                let bundleURL = try resolveBundle(
                    path: value(after: "--app", in: arguments)
                )
                let coordinator = try liveCoordinator(session: liveSession())
                while getppid() == parentPID {
                    do {
                        _ = try await coordinator.maintain(
                            bundleURL: bundleURL,
                            theme: theme
                        )
                    } catch ThemeBridgeCoordinatorError.targetUnavailable {
                        // Renderer replacement can briefly leave the target list empty.
                    } catch ThemeBridgeCoordinatorError.staleSession {
                        return
                    } catch {
                        try? await coordinator.restore(bundleURL: bundleURL)
                        throw error
                    }
                    try await Task.sleep(for: .seconds(2))
                }
                try? await coordinator.restore(bundleURL: bundleURL)
#if HABITAT_OFFLINE_FIXTURE
            case "offline-fixture":
                let options = try OfflineThemeFixtureCommand.parse(arguments: arguments)
                try OfflineThemeFixtureCommand.bundled().run(options: options)
                print("offline fixture written: \(options.outputURL.path)")
#endif
            default:
                printUsage()
                Foundation.exit(64)
            }
        } catch {
            print(ThemeBridgeErrorPresenter.line(for: error))
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

    private static func liveCoordinator(session: ThemeSession) throws -> ThemeBridgeCoordinator {
        let processInspector = CodexProcessInspector()
        return ThemeBridgeCoordinator(
            verifier: CodexBundleVerifier(),
            session: session,
            listenerVerifier: LoopbackListenerVerifier(
                commandRunner: LiveBridgeCommandRunner(),
                processInspector: processInspector
            ),
            clientProvider: LiveCDPClientProvider(),
            profileStore: try CompatibilityProfileStore.bundled(),
            compiler: try ThemeCompiler.bundled(),
            restarter: LiveCodexApplicationRestarter()
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
#if HABITAT_OFFLINE_FIXTURE
        print("usage: CodexHabitatThemeBridge verify [app] | start --authorized [app] | status | stop | apply --authorized --theme <id> [--screenshot <png>] [--app <app>] | watch --theme <id> --parent-pid <pid> [--app <app>] | restore [--app <app>] | offline-fixture --profile-version <version> --output <local.json>")
#else
        print("usage: CodexHabitatThemeBridge verify [app] | start --authorized [app] | status | stop | apply --authorized --theme <id> [--screenshot <png>] [--app <app>] | watch --theme <id> --parent-pid <pid> [--app <app>] | restore [--app <app>]")
#endif
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return arguments[index + 1]
    }
}

private enum ThemeBridgeCLIError: Error {
    case invalidTheme
    case invalidParentProcess
}

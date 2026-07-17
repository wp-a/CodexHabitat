import Foundation

enum SessionMetadataActivity: Equatable, Sendable {
    case resting
    case working
    case completed
}

actor SessionMetadataMonitor {
    private struct Fingerprint: Equatable {
        let size: Int
        let modifiedAt: Date
    }

    private let sessionsRoot: URL
    private let activeWindow: TimeInterval
    private let completionHold: TimeInterval
    private let calendar: Calendar
    private let fileManager: FileManager
    private var fingerprints: [String: Fingerprint]?
    private var lastChange: Date?
    private var completionHoldUntil: Date?
    private var wasActive = false

    init(
        sessionsRoot: URL,
        activeWindow: TimeInterval = 2,
        completionHold: TimeInterval = 2,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) {
        self.sessionsRoot = sessionsRoot
        self.activeWindow = activeWindow
        self.completionHold = completionHold
        self.calendar = calendar
        self.fileManager = fileManager
    }

    static func live(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> SessionMetadataMonitor {
        let codexHome: URL
        if let configured = environment["CODEX_HOME"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !configured.isEmpty {
            codexHome = URL(fileURLWithPath: configured, isDirectory: true)
        } else {
            codexHome = homeDirectory.appending(path: ".codex", directoryHint: .isDirectory)
        }
        return SessionMetadataMonitor(
            sessionsRoot: codexHome.appending(path: "sessions", directoryHint: .isDirectory)
        )
    }

    func sample(at now: Date = Date()) -> SessionMetadataActivity? {
        let current = currentFingerprints(at: now)
        guard let previous = fingerprints else {
            fingerprints = current
            return .resting
        }
        fingerprints = current

        if current != previous {
            lastChange = now
            completionHoldUntil = nil
            wasActive = true
            return .working
        }
        if let completionHoldUntil {
            guard now >= completionHoldUntil else { return nil }
            self.completionHoldUntil = nil
            return .resting
        }
        if let lastChange, wasActive,
           now.timeIntervalSince(lastChange) < activeWindow {
            return .working
        }
        if wasActive {
            wasActive = false
            completionHoldUntil = now.addingTimeInterval(completionHold)
            return .completed
        }
        return .resting
    }

    private func currentFingerprints(at date: Date) -> [String: Fingerprint] {
        var result: [String: Fingerprint] = [:]
        let dates = [date, calendar.date(byAdding: .day, value: -1, to: date)].compactMap { $0 }
        for date in dates {
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year,
                  let month = components.month,
                  let day = components.day
            else {
                continue
            }
            let directory = sessionsRoot.appending(
                path: String(format: "%04d/%02d/%02d", year, month, day),
                directoryHint: .isDirectory
            )
            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                ],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for file in files where file.pathExtension == "jsonl" {
                guard let values = try? file.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                ]),
                values.isRegularFile == true,
                let size = values.fileSize,
                let modifiedAt = values.contentModificationDate
                else {
                    continue
                }
                result[file.lastPathComponent] = Fingerprint(
                    size: size,
                    modifiedAt: modifiedAt
                )
            }
        }
        return result
    }
}

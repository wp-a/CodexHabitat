import Foundation
import HabitatCore

public actor SessionTokenMetricsMonitor {
    private struct OutputPoint: Sendable {
        let timestamp: Date
        let outputTokens: Int
    }

    private let sessionsRoot: URL
    private let calendar: Calendar
    private let fileManager: FileManager
    private let parser = CodexTokenEventParser()
    private let initialTailByteLimit: UInt64
    private let maximumReadBytes: Int
    private let speedWindow: TimeInterval

    private var currentFile: URL?
    private var offset: UInt64 = 0
    private var carry = Data()
    private var discardLeadingPartialLine = false
    private var outputPoints: [OutputPoint] = []
    private var latestMetrics: TokenMetricsSummary?

    public init(
        sessionsRoot: URL,
        calendar: Calendar = .current,
        fileManager: FileManager = .default,
        initialTailByteLimit: UInt64 = 1_048_576,
        maximumReadBytes: Int = 1_048_576,
        speedWindow: TimeInterval = 60
    ) {
        self.sessionsRoot = sessionsRoot
        self.calendar = calendar
        self.fileManager = fileManager
        self.initialTailByteLimit = initialTailByteLimit
        self.maximumReadBytes = maximumReadBytes
        self.speedWindow = speedWindow
    }

    public static func live(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> SessionTokenMetricsMonitor {
        let codexHome: URL
        if let configured = environment["CODEX_HOME"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !configured.isEmpty {
            codexHome = URL(fileURLWithPath: configured, isDirectory: true)
        } else {
            codexHome = homeDirectory.appending(path: ".codex", directoryHint: .isDirectory)
        }
        return SessionTokenMetricsMonitor(
            sessionsRoot: codexHome.appending(path: "sessions", directoryHint: .isDirectory)
        )
    }

    public func sample(at now: Date = Date()) async -> TokenMetricsSummary? {
        guard let latestFile = latestSessionFile(at: now),
              let fileSize = fileSize(of: latestFile)
        else {
            reset(file: nil, fileSize: 0)
            return nil
        }

        if currentFile?.standardizedFileURL != latestFile.standardizedFileURL {
            reset(file: latestFile, fileSize: fileSize)
        } else if fileSize < offset {
            reset(file: latestFile, fileSize: fileSize)
        }

        readAvailableBytes(from: latestFile, fileSize: fileSize)
        return latestMetrics
    }

    private func reset(file: URL?, fileSize: UInt64) {
        currentFile = file
        offset = fileSize > initialTailByteLimit ? fileSize - initialTailByteLimit : 0
        carry.removeAll(keepingCapacity: true)
        discardLeadingPartialLine = offset > 0
        outputPoints.removeAll(keepingCapacity: true)
        latestMetrics = nil
    }

    private func readAvailableBytes(from file: URL, fileSize: UInt64) {
        guard fileSize > offset else { return }
        let available = fileSize - offset
        if available > UInt64(maximumReadBytes) {
            offset = fileSize - UInt64(maximumReadBytes)
            carry.removeAll(keepingCapacity: true)
            discardLeadingPartialLine = offset > 0
            outputPoints.removeAll(keepingCapacity: true)
        }

        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            let data = try handle.read(upToCount: maximumReadBytes) ?? Data()
            offset += UInt64(data.count)
            consume(data)
        } catch {
            return
        }
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        carry.append(data)
        if discardLeadingPartialLine {
            guard let newline = carry.firstIndex(of: 0x0A) else {
                if carry.count > 512 * 1024 { carry.removeAll(keepingCapacity: true) }
                return
            }
            carry.removeSubrange(carry.startIndex...newline)
            discardLeadingPartialLine = false
        }

        while let newline = carry.firstIndex(of: 0x0A) {
            let line = Data(carry[..<newline])
            carry.removeSubrange(carry.startIndex...newline)
            guard let event = parser.parse(line) else { continue }
            accept(event)
        }
        if carry.count > 512 * 1024 {
            carry.removeAll(keepingCapacity: true)
        }
    }

    private func accept(_ event: CodexTokenEvent) {
        outputPoints.append(OutputPoint(
            timestamp: event.timestamp,
            outputTokens: event.metrics.outputTokens
        ))
        let cutoff = event.timestamp.addingTimeInterval(-speedWindow)
        outputPoints.removeAll { $0.timestamp < cutoff }
        if outputPoints.count > 64 {
            outputPoints.removeFirst(outputPoints.count - 64)
        }
        latestMetrics = event.metrics.withOutputTokensPerMinute(outputSpeed())
    }

    private func outputSpeed() -> Double? {
        guard let first = outputPoints.first,
              let last = outputPoints.last,
              last.timestamp > first.timestamp,
              last.outputTokens >= first.outputTokens
        else {
            return nil
        }
        let seconds = last.timestamp.timeIntervalSince(first.timestamp)
        return Double(last.outputTokens - first.outputTokens) / seconds * 60
    }

    private func latestSessionFile(at date: Date) -> URL? {
        let dates = [date, calendar.date(byAdding: .day, value: -1, to: date)].compactMap { $0 }
        var candidates: [(url: URL, modifiedAt: Date)] = []
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
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for file in files where file.pathExtension == "jsonl" {
                guard let values = try? file.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .contentModificationDateKey,
                ]),
                values.isRegularFile == true,
                let modifiedAt = values.contentModificationDate
                else {
                    continue
                }
                candidates.append((file, modifiedAt))
            }
        }
        return candidates.max { lhs, rhs in
            if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt < rhs.modifiedAt }
            return lhs.url.lastPathComponent < rhs.url.lastPathComponent
        }?.url
    }

    private func fileSize(of url: URL) -> UInt64? {
        guard let value = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              value >= 0
        else {
            return nil
        }
        return UInt64(value)
    }
}

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
    private let recentOutputWindow: TimeInterval
    private let threadIDHasher: (@Sendable (String) -> String)?

    private var currentFile: URL?
    private var offset: UInt64 = 0
    private var carry = Data()
    private var discardLeadingPartialLine = false
    private var outputPoints: [OutputPoint] = []
    private var latestMetrics: TokenMetricsSummary?
    private var preferredThreadIDHash: String?
    private var preferredFile: URL?

    public init(
        sessionsRoot: URL,
        calendar: Calendar = .current,
        fileManager: FileManager = .default,
        initialTailByteLimit: UInt64 = 1_048_576,
        maximumReadBytes: Int = 1_048_576,
        recentOutputWindow: TimeInterval = 60,
        threadIDHasher: (@Sendable (String) -> String)? = nil
    ) {
        self.sessionsRoot = sessionsRoot
        self.calendar = calendar
        self.fileManager = fileManager
        self.initialTailByteLimit = initialTailByteLimit
        self.maximumReadBytes = maximumReadBytes
        self.recentOutputWindow = recentOutputWindow
        self.threadIDHasher = threadIDHasher
    }

    public static func live(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        threadIDHasher: (@Sendable (String) -> String)? = nil
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
            sessionsRoot: codexHome.appending(path: "sessions", directoryHint: .isDirectory),
            threadIDHasher: threadIDHasher
        )
    }

    public func selectThread(idHash: String?) {
        guard preferredThreadIDHash != idHash else { return }
        preferredThreadIDHash = idHash
        preferredFile = idHash.flatMap { findSessionFile(matching: $0) }
        reset(file: nil, fileSize: 0)
    }

    public func sample(at now: Date = Date()) async -> TokenMetricsSummary? {
        guard let latestFile = selectedSessionFile(at: now),
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
        expireRecentOutput(at: now)
        return latestMetrics
    }

    private func selectedSessionFile(at now: Date) -> URL? {
        guard let preferredThreadIDHash else { return latestSessionFile(at: now) }
        if let preferredFile, fileSize(of: preferredFile) != nil {
            return preferredFile
        }
        preferredFile = findSessionFile(matching: preferredThreadIDHash)
        return preferredFile
    }

    private func findSessionFile(matching idHash: String) -> URL? {
        guard let threadIDHasher,
              let enumerator = fileManager.enumerator(
                at: sessionsRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              )
        else {
            return nil
        }
        var inspected = 0
        for case let file as URL in enumerator {
            guard inspected < 20_000 else { break }
            inspected += 1
            guard file.pathExtension == "jsonl",
                  let sessionID = Self.sessionID(from: file),
                  threadIDHasher(sessionID) == idHash,
                  (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            else {
                continue
            }
            return file
        }
        return nil
    }

    private static func sessionID(from file: URL) -> String? {
        let name = file.deletingPathExtension().lastPathComponent
        guard name.count >= 36 else { return nil }
        let candidate = String(name.suffix(36))
        return UUID(uuidString: candidate) == nil ? nil : candidate
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
        if let last = outputPoints.last, event.metrics.outputTokens < last.outputTokens {
            outputPoints.removeAll(keepingCapacity: true)
        }
        outputPoints.append(OutputPoint(
            timestamp: event.timestamp,
            outputTokens: event.metrics.outputTokens
        ))
        pruneOutputPoints(before: event.timestamp.addingTimeInterval(-recentOutputWindow))
        if outputPoints.count > 64 {
            outputPoints.removeFirst(outputPoints.count - 64)
        }
        latestMetrics = event.metrics.withRecentOutputTokens(recentOutput(at: event.timestamp))
    }

    private func recentOutput(at now: Date) -> Int? {
        guard let first = outputPoints.first,
              let last = outputPoints.last,
              outputPoints.count > 1,
              last.timestamp >= now.addingTimeInterval(-recentOutputWindow),
              last.outputTokens >= first.outputTokens
        else {
            return nil
        }
        return last.outputTokens - first.outputTokens
    }

    private func expireRecentOutput(at now: Date) {
        pruneOutputPoints(before: now.addingTimeInterval(-recentOutputWindow))
        guard let latestMetrics else { return }
        self.latestMetrics = latestMetrics.withRecentOutputTokens(recentOutput(at: now))
    }

    private func pruneOutputPoints(before cutoff: Date) {
        guard let firstInsideWindow = outputPoints.firstIndex(where: { $0.timestamp >= cutoff }) else {
            if let last = outputPoints.last {
                outputPoints = [last]
            }
            return
        }
        guard firstInsideWindow > 1 else { return }
        outputPoints.removeFirst(firstInsideWindow - 1)
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

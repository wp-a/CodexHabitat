import CodexConnector
import Foundation
import HabitatCore
import SwiftUI

enum CompanionScreenSnapPreset: String, CaseIterable, Identifiable, Sendable {
    case notchIsland
    case topRight
    case bottomRight
    case bottomLeft

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .notchIsland: "Notch Island"
        case .topRight: "Top Right"
        case .bottomRight: "Bottom Right"
        case .bottomLeft: "Bottom Left"
        }
    }

    var symbol: String {
        switch self {
        case .notchIsland: "menubar.dock.rectangle"
        case .topRight: "inset.filled.toptrailing.rectangle"
        case .bottomRight: "inset.filled.bottomtrailing.rectangle"
        case .bottomLeft: "inset.filled.bottomleading.rectangle"
        }
    }

    var relativeX: Double {
        switch self {
        case .notchIsland: 0.58
        case .topRight: 0.98
        case .bottomRight: 0.98
        case .bottomLeft: 0.02
        }
    }

    var relativeY: Double {
        switch self {
        case .notchIsland: 0.99
        case .topRight: 0.96
        case .bottomRight: 0.04
        case .bottomLeft: 0.04
        }
    }
}

enum CompanionEvolutionTier: String, Equatable, Sendable {
    case hatchling
    case apprentice
    case ranger
    case vanguard
    case mythic

    static func resolve(level: Int) -> Self {
        switch level {
        case ..<5: .hatchling
        case 5..<12: .apprentice
        case 12..<25: .ranger
        case 25..<40: .vanguard
        default: .mythic
        }
    }

    var titleKey: String {
        switch self {
        case .hatchling: "Hatchling"
        case .apprentice: "Apprentice"
        case .ranger: "Ranger"
        case .vanguard: "Vanguard"
        case .mythic: "Mythic"
        }
    }

    var symbol: String {
        switch self {
        case .hatchling: "sparkle"
        case .apprentice: "leaf.fill"
        case .ranger: "bolt.shield.fill"
        case .vanguard: "flame.fill"
        case .mythic: "crown.fill"
        }
    }
}

struct MultiAgentRadarEntry: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case activeNow
        case activeToday
        case idle
        case notDetected

        var titleKey: String {
            switch self {
            case .activeNow: "Working"
            case .activeToday: "Active today"
            case .idle: "Resting"
            case .notDetected: "Not detected"
            }
        }
    }

    let id: String
    let name: String
    let symbol: String
    let tintHex: String
    let sessionCount: Int
    let todaySessions: Int
    let status: Status
}

struct DailyActivityBucket: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let shortWeekday: String
    let sessionCount: Int
    let tokenCount: Int
    let isToday: Bool
}

struct CompanionAchievement: Identifiable, Equatable, Sendable {
    let id: String
    let titleKey: String
    let symbol: String
    let isUnlocked: Bool
}

struct CompanionProgressionSnapshot: Equatable, Sendable {
    let level: Int
    let tier: CompanionEvolutionTier
    let levelProgress: Double
    let totalXP: Int
    let streakDays: Int
    let energyPercent: Int
    let totalSessions: Int
    let totalTokens: Int
    let agents: [MultiAgentRadarEntry]
    let dailyBuckets: [DailyActivityBucket]
    let achievements: [CompanionAchievement]

    static let placeholder = CompanionProgressionSnapshot(
        level: 1,
        tier: .hatchling,
        levelProgress: 0.25,
        totalXP: 120,
        streakDays: 1,
        energyPercent: 85,
        totalSessions: 0,
        totalTokens: 0,
        agents: [
            MultiAgentRadarEntry(
                id: "codex",
                name: "OpenAI Codex",
                symbol: "terminal.fill",
                tintHex: "#10B981",
                sessionCount: 0,
                todaySessions: 0,
                status: .idle
            ),
            MultiAgentRadarEntry(
                id: "claude",
                name: "Claude Code",
                symbol: "sparkles",
                tintHex: "#E07A5F",
                sessionCount: 0,
                todaySessions: 0,
                status: .notDetected
            ),
            MultiAgentRadarEntry(
                id: "antigravity",
                name: "Antigravity",
                symbol: "bolt.horizontal.circle.fill",
                tintHex: "#38BDF8",
                sessionCount: 0,
                todaySessions: 0,
                status: .notDetected
            ),
        ],
        dailyBuckets: [],
        achievements: []
    )
}

@MainActor
final class CompanionProgressionStore: ObservableObject {
    static let shared = CompanionProgressionStore()

    @Published private(set) var snapshot = CompanionProgressionSnapshot.placeholder
    private var bonusXP: Int
    private var energyBoost: Int
    private var refreshTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    private enum StorageKeys {
        static let bonusXP = "habitat.companion.bonusXP"
        static let energyBoost = "habitat.companion.energyBoost"
    }

    init() {
        bonusXP = max(0, defaults.integer(forKey: StorageKeys.bonusXP))
        energyBoost = min(max(defaults.integer(forKey: StorageKeys.energyBoost), 0), 100)
    }

    func refreshIfNeeded() {
        guard refreshTask == nil else { return }
        let currentBonusXP = bonusXP
        let currentEnergyBoost = energyBoost
        refreshTask = Task { [weak self] in
            let computed = await Task.detached(priority: .utility) {
                Self.scanLocalActivity(
                    bonusXP: currentBonusXP,
                    energyBoost: currentEnergyBoost
                )
            }.value
            guard let self else { return }
            self.snapshot = computed
            self.refreshTask = nil
        }
    }

    func recordCareInteraction(xp: Int, energyDelta: Int) {
        bonusXP = min(bonusXP + max(0, xp), 500_000)
        energyBoost = min(max(energyBoost + energyDelta, 0), 40)
        defaults.set(bonusXP, forKey: StorageKeys.bonusXP)
        defaults.set(energyBoost, forKey: StorageKeys.energyBoost)
        applyCareOverlayToCurrentSnapshot()
    }

    private func applyCareOverlayToCurrentSnapshot() {
        let baseXP = max(0, snapshot.totalXP) + 50
        let levelInfo = Self.resolveLevel(totalXP: baseXP)
        let nextEnergy = min(100, snapshot.energyPercent + 18)
        snapshot = CompanionProgressionSnapshot(
            level: levelInfo.level,
            tier: CompanionEvolutionTier.resolve(level: levelInfo.level),
            levelProgress: levelInfo.progress,
            totalXP: baseXP,
            streakDays: snapshot.streakDays,
            energyPercent: nextEnergy,
            totalSessions: snapshot.totalSessions,
            totalTokens: snapshot.totalTokens,
            agents: snapshot.agents,
            dailyBuckets: snapshot.dailyBuckets,
            achievements: snapshot.achievements
        )
    }

    nonisolated static func resolveLevel(totalXP: Int) -> (level: Int, progress: Double) {
        let safeXP = max(0, totalXP)
        // Smooth RPG curve: each level costs 320 + level * 85 XP
        var level = 1
        var remaining = safeXP
        while level < 99 {
            let needed = 320 + level * 85
            if remaining < needed {
                return (level, Double(remaining) / Double(needed))
            }
            remaining -= needed
            level += 1
        }
        return (99, 1.0)
    }

    nonisolated private static func scanLocalActivity(
        bonusXP: Int,
        energyBoost: Int,
        now: Date = Date()
    ) -> CompanionProgressionSnapshot {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)

        let codexRoot = home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
        let claudeRoot = home.appending(path: ".claude/projects", directoryHint: .isDirectory)
        let geminiRoot = home.appending(path: ".gemini/antigravity-cli/brain", directoryHint: .isDirectory)

        let codexFiles = collectJSONLMetadata(in: codexRoot, maxFiles: 1_500, fileManager: fm)
        let claudeFiles = collectJSONLMetadata(in: claudeRoot, maxFiles: 800, fileManager: fm)
        let geminiFiles = collectGeminiTranscriptMetadata(in: geminiRoot, fileManager: fm)

        var daySessionCounts: [Date: Int] = [:]
        var hasLateNightSession = false
        for item in codexFiles + claudeFiles + geminiFiles {
            let day = calendar.startOfDay(for: item.modifiedAt)
            daySessionCounts[day, default: 0] += 1
            let hour = calendar.component(.hour, from: item.modifiedAt)
            if hour >= 23 || hour < 4 {
                hasLateNightSession = true
            }
        }

        // Extract sanitized token totals for recent 14 days of Codex sessions (tail-only read)
        let parser = CodexTokenEventParser()
        var dayTokens: [Date: Int] = [:]
        var cumulativeSampledTokens = 0
        let cutoff14d = calendar.date(byAdding: .day, value: -14, to: todayStart) ?? todayStart
        for item in codexFiles {
            let day = calendar.startOfDay(for: item.modifiedAt)
            guard day >= cutoff14d || codexFiles.count <= 60 else { continue }
            if let tokens = tailTotalTokens(of: item.url, size: item.size, parser: parser) {
                dayTokens[day, default: 0] += tokens
                cumulativeSampledTokens += tokens
            }
        }

        // Build 7-day chart buckets (oldest -> today)
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: L10n.current.resolvedLanguage)
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")

        var buckets: [DailyActivityBucket] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: todayStart) else {
                continue
            }
            let key = String(format: "d-%d", offset)
            let label = offset == 0 ? L10n.text("Today") : weekdayFormatter.string(from: date)
            buckets.append(DailyActivityBucket(
                id: key,
                date: date,
                shortWeekday: label,
                sessionCount: daySessionCounts[date, default: 0],
                tokenCount: dayTokens[date, default: 0],
                isToday: offset == 0
            ))
        }

        // Calculate consecutive active streak up to today/yesterday
        var streak = 0
        var cursor = daySessionCounts[todayStart, default: 0] > 0
            ? todayStart
            : (calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart)
        while daySessionCounts[cursor, default: 0] > 0, streak < 365 {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        let codexEntry = makeAgentEntry(
            id: "codex",
            name: "OpenAI Codex",
            symbol: "terminal.fill",
            tintHex: "#10B981",
            files: codexFiles,
            todayStart: todayStart,
            now: now
        )
        let claudeEntry = makeAgentEntry(
            id: "claude",
            name: "Claude Code",
            symbol: "sparkles",
            tintHex: "#E07A5F",
            files: claudeFiles,
            todayStart: todayStart,
            now: now
        )
        let geminiEntry = makeAgentEntry(
            id: "antigravity",
            name: "Antigravity",
            symbol: "bolt.horizontal.circle.fill",
            tintHex: "#38BDF8",
            files: geminiFiles,
            todayStart: todayStart,
            now: now
        )

        let agents = [codexEntry, claudeEntry, geminiEntry]
        let detectedAgentCount = agents.filter { $0.sessionCount > 0 }.count
        let totalSessions = codexFiles.count + claudeFiles.count + geminiFiles.count
        let tokenXP = cumulativeSampledTokens > 0
            ? Int(log10(Double(max(10, cumulativeSampledTokens))) * 620)
            : 0
        let totalXP = totalSessions * 135 + streak * 260 + tokenXP + bonusXP
        let levelInfo = resolveLevel(totalXP: totalXP)

        let todayActive = daySessionCounts[todayStart, default: 0]
        let baseEnergy = todayActive > 0 ? min(96, 68 + todayActive * 6) : 64
        let energy = min(100, baseEnergy + energyBoost)

        let achievements = [
            CompanionAchievement(
                id: "first-spark",
                titleKey: "First Spark",
                symbol: "sparkles",
                isUnlocked: totalSessions >= 1
            ),
            CompanionAchievement(
                id: "centurion",
                titleKey: "100 Sessions",
                symbol: "medal.fill",
                isUnlocked: totalSessions >= 100
            ),
            CompanionAchievement(
                id: "polyglot",
                titleKey: "Multi-Agent",
                symbol: "point.3.connected.trianglepath.dotted",
                isUnlocked: detectedAgentCount >= 2
            ),
            CompanionAchievement(
                id: "streak-3",
                titleKey: "Hot Streak",
                symbol: "flame.fill",
                isUnlocked: streak >= 3
            ),
            CompanionAchievement(
                id: "singularity",
                titleKey: "1B Tokens",
                symbol: "bolt.ring.closed",
                isUnlocked: cumulativeSampledTokens >= 1_000_000_000
            ),
            CompanionAchievement(
                id: "night-owl",
                titleKey: "Night Owl",
                symbol: "moon.stars.fill",
                isUnlocked: hasLateNightSession
            ),
        ]

        return CompanionProgressionSnapshot(
            level: levelInfo.level,
            tier: CompanionEvolutionTier.resolve(level: levelInfo.level),
            levelProgress: levelInfo.progress,
            totalXP: totalXP,
            streakDays: streak,
            energyPercent: energy,
            totalSessions: totalSessions,
            totalTokens: cumulativeSampledTokens,
            agents: agents,
            dailyBuckets: buckets,
            achievements: achievements
        )
    }

    private struct FileMeta {
        let url: URL
        let modifiedAt: Date
        let size: UInt64
    }

    nonisolated private static func collectJSONLMetadata(
        in root: URL,
        maxFiles: Int,
        fileManager: FileManager
    ) -> [FileMeta] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        var results: [FileMeta] = []
        var scanned = 0
        for case let url as URL in enumerator {
            guard scanned < maxFiles * 3 else { break }
            scanned += 1
            guard url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: [
                      .isRegularFileKey, .contentModificationDateKey, .fileSizeKey,
                  ]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate
            else {
                continue
            }
            let size = UInt64(max(0, values.fileSize ?? 0))
            results.append(FileMeta(url: url, modifiedAt: modifiedAt, size: size))
            if results.count >= maxFiles { break }
        }
        return results
    }

    nonisolated private static func collectGeminiTranscriptMetadata(
        in brainRoot: URL,
        fileManager: FileManager
    ) -> [FileMeta] {
        guard let dirs = try? fileManager.contentsOfDirectory(
            at: brainRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var results: [FileMeta] = []
        for dir in dirs.prefix(200) {
            let transcript = dir.appending(path: ".system_generated/logs/transcript.jsonl")
            guard let values = try? transcript.resourceValues(forKeys: [
                .isRegularFileKey, .contentModificationDateKey, .fileSizeKey,
            ]),
            values.isRegularFile == true,
            let modifiedAt = values.contentModificationDate
            else {
                continue
            }
            results.append(FileMeta(
                url: transcript,
                modifiedAt: modifiedAt,
                size: UInt64(max(0, values.fileSize ?? 0))
            ))
        }
        return results
    }

    nonisolated private static func tailTotalTokens(
        of url: URL,
        size: UInt64,
        parser: CodexTokenEventParser
    ) -> Int? {
        guard size > 0, let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let tailWindow: UInt64 = 48 * 1_024
        let offset = size > tailWindow ? size - tailWindow : 0
        do {
            try handle.seek(toOffset: offset)
            guard let data = try handle.readToEnd(), !data.isEmpty else { return nil }
            let lines = data.split(separator: 0x0A)
            let startIdx = offset > 0 ? min(1, lines.count) : 0
            for slice in lines[startIdx...].reversed() {
                if let event = parser.parse(Data(slice)) {
                    return event.metrics.totalTokens
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    nonisolated private static func makeAgentEntry(
        id: String,
        name: String,
        symbol: String,
        tintHex: String,
        files: [FileMeta],
        todayStart: Date,
        now: Date
    ) -> MultiAgentRadarEntry {
        guard !files.isEmpty else {
            return MultiAgentRadarEntry(
                id: id,
                name: name,
                symbol: symbol,
                tintHex: tintHex,
                sessionCount: 0,
                todaySessions: 0,
                status: .notDetected
            )
        }
        let latest = files.map(\.modifiedAt).max() ?? .distantPast
        let todayCount = files.filter { $0.modifiedAt >= todayStart }.count
        let status: MultiAgentRadarEntry.Status
        if now.timeIntervalSince(latest) <= 25 {
            status = .activeNow
        } else if latest >= todayStart {
            status = .activeToday
        } else {
            status = .idle
        }
        return MultiAgentRadarEntry(
            id: id,
            name: name,
            symbol: symbol,
            tintHex: tintHex,
            sessionCount: files.count,
            todaySessions: todayCount,
            status: status
        )
    }
}

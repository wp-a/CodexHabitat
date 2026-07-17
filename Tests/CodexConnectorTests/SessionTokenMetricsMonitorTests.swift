import Foundation
import HabitatCore
import Testing
@testable import CodexConnector

@Test
func sessionTokenMonitorReadsAppendsCalculatesRecentOutputAndIgnoresPartialTails() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatTokenMetrics-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let day = root.appending(path: "2026/07/17", directoryHint: .isDirectory)
    let session = day.appending(path: "rollout-first.jsonl")
    try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try Data((tokenLine(timestamp: "2026-07-17T04:00:00.000Z", output: 100) + "\n").utf8)
        .write(to: session)
    let monitor = SessionTokenMetricsMonitor(sessionsRoot: root, calendar: utcCalendar)
    let start = Date(timeIntervalSince1970: 1_784_260_800)

    let first = try #require(await monitor.sample(at: start))
    #expect(first.outputTokens == 100)
    #expect(first.recentOutputTokens == nil)

    try append("{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\"}}\n", to: session)
    let secondLine = tokenLine(timestamp: "2026-07-17T04:00:20.000Z", output: 140)
    let split = secondLine.index(secondLine.startIndex, offsetBy: secondLine.count / 2)
    try append(String(secondLine[..<split]), to: session)
    #expect(await monitor.sample(at: start.addingTimeInterval(10))?.outputTokens == 100)

    try append(String(secondLine[split...]) + "\n", to: session)
    let second = try #require(await monitor.sample(at: start.addingTimeInterval(20)))
    #expect(second.outputTokens == 140)
    #expect(second.recentOutputTokens == 40)
    #expect(second.contextUsedPercent == 50)
}

@Test
func sessionTokenMonitorResetsRecentOutputWhenTheLatestSessionChanges() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatTokenMetricsSwitch-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let day = root.appending(path: "2026/07/17", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let firstURL = day.appending(path: "rollout-first.jsonl")
    let secondURL = day.appending(path: "rollout-second.jsonl")
    try Data((tokenLine(timestamp: "2026-07-17T04:00:00.000Z", output: 100) + "\n").utf8)
        .write(to: firstURL)
    let start = Date(timeIntervalSince1970: 1_784_260_800)
    try FileManager.default.setAttributes(
        [.modificationDate: start],
        ofItemAtPath: firstURL.path
    )
    let monitor = SessionTokenMetricsMonitor(sessionsRoot: root, calendar: utcCalendar)
    _ = await monitor.sample(at: start)

    try Data((tokenLine(timestamp: "2026-07-17T04:01:00.000Z", output: 12) + "\n").utf8)
        .write(to: secondURL)
    try FileManager.default.setAttributes(
        [.modificationDate: start.addingTimeInterval(60)],
        ofItemAtPath: secondURL.path
    )
    let switched = try #require(await monitor.sample(at: start.addingTimeInterval(60)))

    #expect(switched.outputTokens == 12)
    #expect(switched.recentOutputTokens == nil)
}

@Test
func sessionTokenRecentOutputExpiresWithoutANewTokenEvent() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatTokenMetricsExpiry-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let day = root.appending(path: "2026/07/17", directoryHint: .isDirectory)
    let session = day.appending(path: "rollout-first.jsonl")
    try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data((
        tokenLine(timestamp: "2026-07-17T04:00:00.000Z", output: 100) + "\n"
            + tokenLine(timestamp: "2026-07-17T04:00:20.000Z", output: 140) + "\n"
    ).utf8).write(to: session)
    let monitor = SessionTokenMetricsMonitor(sessionsRoot: root, calendar: utcCalendar)
    let start = Date(timeIntervalSince1970: 1_784_260_800)

    #expect(await monitor.sample(at: start.addingTimeInterval(20))?.recentOutputTokens == 40)
    #expect(await monitor.sample(at: start.addingTimeInterval(81))?.recentOutputTokens == nil)
}

@Test
func sessionTokenRecentOutputResetsWhenTheCumulativeCounterDecreases() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatTokenMetricsCounterReset-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let day = root.appending(path: "2026/07/17", directoryHint: .isDirectory)
    let session = day.appending(path: "rollout-first.jsonl")
    try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data((
        tokenLine(timestamp: "2026-07-17T04:00:00.000Z", output: 100) + "\n"
            + tokenLine(timestamp: "2026-07-17T04:00:20.000Z", output: 140) + "\n"
            + tokenLine(timestamp: "2026-07-17T04:00:30.000Z", output: 12) + "\n"
    ).utf8).write(to: session)
    let monitor = SessionTokenMetricsMonitor(sessionsRoot: root, calendar: utcCalendar)

    let metrics = try #require(await monitor.sample(
        at: Date(timeIntervalSince1970: 1_784_260_830)
    ))
    #expect(metrics.outputTokens == 12)
    #expect(metrics.recentOutputTokens == nil)
}

@Test
func preferredThreadKeepsMetricsBoundToTheMatchingSessionAcrossParallelUpdates() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatTokenMetricsPreferred-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let oldDay = root.appending(path: "2026/07/10", directoryHint: .isDirectory)
    let today = root.appending(path: "2026/07/17", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: oldDay, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: today, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let preferredID = "019F1234-1111-7222-8333-123456789ABC"
    let competingID = "019f1234-4444-7555-8666-abcdef123456"
    let preferred = oldDay.appending(path: "rollout-2026-07-10T10-00-00-\(preferredID).jsonl")
    let competing = today.appending(path: "rollout-2026-07-17T10-00-00-\(competingID).jsonl")
    try Data((tokenLine(timestamp: "2026-07-17T04:00:00.000Z", output: 40) + "\n").utf8)
        .write(to: preferred)
    try Data((tokenLine(timestamp: "2026-07-17T04:00:00.000Z", output: 900) + "\n").utf8)
        .write(to: competing)
    try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSince1970: 1_784_260_900)],
        ofItemAtPath: competing.path
    )
    let monitor = SessionTokenMetricsMonitor(
        sessionsRoot: root,
        calendar: utcCalendar,
        threadIDHasher: { "hash:\($0)" }
    )

    await monitor.selectThread(idHash: "hash:\(preferredID)")
    let metrics = try #require(
        await monitor.sample(at: Date(timeIntervalSince1970: 1_784_260_900))
    )

    #expect(metrics.outputTokens == 40)
}

private func tokenLine(timestamp: String, output: Int) -> String {
    """
    {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":600,"output_tokens":\(output),"reasoning_output_tokens":20,"total_tokens":\(1000 + output)},"last_token_usage":{"input_tokens":500,"cached_input_tokens":300,"output_tokens":40,"reasoning_output_tokens":10,"total_tokens":540},"model_context_window":1000}}}
    """
}

private func append(_ string: String, to url: URL) throws {
    let handle = try FileHandle(forWritingTo: url)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(string.utf8))
    try handle.close()
}

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

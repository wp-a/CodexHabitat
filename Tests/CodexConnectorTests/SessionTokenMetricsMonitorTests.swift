import Foundation
import HabitatCore
import Testing
@testable import CodexConnector

@Test
func sessionTokenMonitorReadsAppendsCalculatesSpeedAndIgnoresPartialTails() async throws {
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
    #expect(first.outputTokensPerMinute == nil)

    try append("{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\"}}\n", to: session)
    let secondLine = tokenLine(timestamp: "2026-07-17T04:00:20.000Z", output: 140)
    let split = secondLine.index(secondLine.startIndex, offsetBy: secondLine.count / 2)
    try append(String(secondLine[..<split]), to: session)
    #expect(await monitor.sample(at: start.addingTimeInterval(10))?.outputTokens == 100)

    try append(String(secondLine[split...]) + "\n", to: session)
    let second = try #require(await monitor.sample(at: start.addingTimeInterval(20)))
    #expect(second.outputTokens == 140)
    #expect(second.outputTokensPerMinute == 120)
    #expect(second.contextUsedPercent == 50)
}

@Test
func sessionTokenMonitorResetsSpeedWhenTheLatestSessionChanges() async throws {
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
    #expect(switched.outputTokensPerMinute == nil)
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

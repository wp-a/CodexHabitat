import Foundation
import Testing
@testable import CodexHabitatApp

@Test
func sessionMetadataMonitorInfersActivityWithoutReadingContents() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatSessionMetadata-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let day = root.appending(path: "2026/07/17", directoryHint: .isDirectory)
    let session = day.appending(path: "rollout-test.jsonl")
    try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
    try Data("private payload".utf8).write(to: session)
    defer { try? FileManager.default.removeItem(at: root) }

    let monitor = SessionMetadataMonitor(
        sessionsRoot: root,
        activeWindow: 2,
        completionHold: 2,
        calendar: utcCalendar
    )
    let start = utcCalendar.date(from: DateComponents(
        year: 2026,
        month: 7,
        day: 17,
        hour: 12
    ))!

    #expect(await monitor.sample(at: start) == .resting)

    try FileHandle(forWritingTo: session).closeAfterWriting(Data(" more".utf8))
    #expect(await monitor.sample(at: start.addingTimeInterval(0.5)) == .working)
    #expect(await monitor.sample(at: start.addingTimeInterval(1.5)) == .working)
    #expect(await monitor.sample(at: start.addingTimeInterval(3)) == .completed)
    #expect(await monitor.sample(at: start.addingTimeInterval(4)) == nil)
    #expect(await monitor.sample(at: start.addingTimeInterval(5.5)) == .resting)
}

@Test
func missingSessionDirectoryFallsBackToResting() async {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatMissingSessions-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let monitor = SessionMetadataMonitor(
        sessionsRoot: root,
        calendar: utcCalendar
    )

    let date = utcCalendar.date(from: DateComponents(year: 2026, month: 7, day: 17))!
    #expect(await monitor.sample(at: date) == .resting)
}

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private extension FileHandle {
    func closeAfterWriting(_ data: Data) throws {
        try seekToEnd()
        try write(contentsOf: data)
        try close()
    }
}

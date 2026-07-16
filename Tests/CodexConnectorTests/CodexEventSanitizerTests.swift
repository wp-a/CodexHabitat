import Foundation
import Testing
@testable import CodexConnector

@Test
func activeThreadFixtureBecomesSanitizedStatus() throws {
    let sanitizer = CodexEventSanitizer(salt: Data(repeating: 0x11, count: 32))
    let event = try #require(sanitizer.sanitize(try fixture(named: "active-thread")))

    #expect(event.category == .threadStatusChanged)
    #expect(event.status == .active)
    #expect(event.timestamp == Date(timeIntervalSince1970: 1_784_188_800))
    #expect(event.threadIDHash?.count == 64)
    #expect(event.threadIDHash != "thread-example-001")
}

@Test
func sensitiveFieldsNeverEnterPublicEvent() throws {
    let sanitizer = CodexEventSanitizer(salt: Data(repeating: 0x22, count: 32))
    let event = try #require(sanitizer.sanitize(try fixture(named: "sensitive-item")))
    let encoded = try JSONEncoder().encode(event)
    let text = String(decoding: encoded, as: UTF8.self)

    #expect(event.category == .turnCompleted)
    #expect(!text.contains("example-workspace"))
    #expect(!text.contains("invented private payload"))
    #expect(!text.contains("invented private result"))
    #expect(!text.contains("thread-example-002"))
}

@Test
func hashingIsStablePerSaltAndDifferentAcrossSalts() throws {
    let message = try fixture(named: "active-thread")
    let first = CodexEventSanitizer(salt: Data(repeating: 0x01, count: 32))
    let second = CodexEventSanitizer(salt: Data(repeating: 0x02, count: 32))

    let firstHash = try #require(first.sanitize(message)?.threadIDHash)
    #expect(first.sanitize(message)?.threadIDHash == firstHash)
    #expect(second.sanitize(message)?.threadIDHash != firstHash)
}

@Test
func allowlistedMethodsMapAndUnknownMethodsAreIgnored() throws {
    let sanitizer = CodexEventSanitizer(salt: Data(repeating: 0x33, count: 32))
    let mappings: [(JSONRPCMessage, CodexEventCategory)] = [
        (.notification(method: "thread/started", params: threadParams), .threadStarted),
        (.notification(method: "turn/started", params: threadParams), .turnStarted),
        (.notification(method: "turn/completed", params: threadParams), .turnCompleted),
        (.request(id: .integer(9), method: "item/commandExecution/requestApproval", params: threadParams), .attentionRequired),
        (.request(id: .integer(10), method: "item/tool/requestUserInput", params: threadParams), .attentionRequired),
        (.notification(method: "error", params: threadParams), .error),
    ]

    for (message, category) in mappings {
        #expect(sanitizer.sanitize(message)?.category == category)
    }
    #expect(sanitizer.sanitize(.notification(method: "item/completed", params: threadParams)) == nil)
}

@Test
func rateLimitUpdateKeepsOnlyPercentagesAndResetTimes() throws {
    let sanitizer = CodexEventSanitizer(salt: Data(repeating: 0x44, count: 32))
    let params = JSONValue.object([
        "rateLimits": .object([
            "primary": .object([
                "usedPercent": .number(12),
                "resetsAt": .number(1_784_192_400),
            ]),
            "secondary": .object([
                "usedPercent": .number(34),
                "resetAt": .string("2026-07-23T08:00:00Z"),
            ]),
        ]),
    ])

    let event = try #require(
        sanitizer.sanitize(
            .notification(method: "account/rateLimits/updated", params: params)
        )
    )

    #expect(event.category == .rateLimitsUpdated)
    #expect(event.rateLimits?.primaryUsedPercent == 12)
    #expect(event.rateLimits?.primaryResetAt == Date(timeIntervalSince1970: 1_784_192_400))
    #expect(event.rateLimits?.secondaryUsedPercent == 34)
    #expect(event.rateLimits?.secondaryResetAt == Date(timeIntervalSince1970: 1_784_793_600))
}

@Test
func hashSaltIsCreatedOnceWithPrivatePermissions() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexEventSaltTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = EventHashSaltStore(root: root)

    let first = try store.loadOrCreate()
    let second = try store.loadOrCreate()
    let attributes = try FileManager.default.attributesOfItem(
        atPath: root.appending(path: "EventHashSalt").path
    )
    let mode = try #require(attributes[.posixPermissions] as? NSNumber)

    #expect(first.count == 32)
    #expect(second == first)
    #expect(mode.intValue & 0o777 == 0o600)
}

private let threadParams = JSONValue.object([
    "threadId": .string("thread-example-003"),
    "timestamp": .string("2026-07-16T08:02:00Z"),
])

private func fixture(named name: String) throws -> JSONRPCMessage {
    let url = try #require(
        Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures"
        )
    )
    return try JSONRPCCodec.decode(Data(contentsOf: url))
}

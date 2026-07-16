import Foundation
import Testing
@testable import CodexConnector

private let fixedWebSocketKey = "dGhlIHNhbXBsZSBub25jZQ=="

@Test
func controlClientUpgradesAndInitializesInOrder() async throws {
    let transport = FakeByteTransport(reads: [
        .success(handshakeResponse()),
        .success(try serverText(.response(id: .integer(1), result: .object([:])))),
    ])
    let client = CodexControlClient(
        transport: transport,
        sanitizer: CodexEventSanitizer(salt: Data(repeating: 1, count: 32)),
        webSocketKey: { fixedWebSocketKey }
    )

    try await client.connect()

    let writes = await transport.writes()
    #expect(writes.count == 3)
    #expect(String(decoding: writes[0], as: UTF8.self).hasPrefix("GET / HTTP/1.1\r\n"))

    let initialize = try decodedClientMessage(writes[1])
    guard case let .request(id, method, params) = initialize else {
        Issue.record("Expected initialize request")
        return
    }
    #expect(id == .integer(1))
    #expect(method == "initialize")
    #expect(params?.object?["clientInfo"]?.object?["name"] == .string("codex-habitat"))
    #expect(try decodedClientMessage(writes[2]) == .notification(method: "initialized", params: nil))
}

@Test
func serverErrorMessagesDoNotCrossTheConnectorBoundary() async throws {
    let transport = FakeByteTransport(reads: [
        .success(handshakeResponse()),
        .success(try serverText(.error(
            id: .integer(1),
            error: JSONRPCError(code: -32_600, message: "private prompt at /Users/example")
        ))),
    ])
    let client = makeClient(transport)

    await #expect(throws: CodexControlClientError.serverError(code: -32_600)) {
        try await client.connect()
    }
}

@Test
func queuedNotificationsAreSanitizedBeforePublication() async throws {
    let notification = JSONRPCMessage.notification(
        method: "thread/status/changed",
        params: .object([
            "threadId": .string("private-thread-id"),
            "status": .object(["type": .string("active")]),
            "prompt": .string("must never leave the connector"),
        ])
    )
    let responseAndNotification = try serverText(
        .response(id: .integer(1), result: .object([:]))
    ) + serverText(notification)
    let transport = FakeByteTransport(reads: [
        .success(handshakeResponse()),
        .success(responseAndNotification),
    ])
    let client = makeClient(transport)
    try await client.connect()

    let event = try await client.receiveNextEvent()

    #expect(event.category == .threadStatusChanged)
    #expect(event.status == .active)
    #expect(event.threadIDHash?.count == 64)
    let encoded = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
    #expect(!encoded.contains("private-thread-id"))
    #expect(!encoded.contains("must never leave"))
}

@Test
func concurrentReadResponsesAreRoutedByRequestID() async throws {
    let transport = FakeByteTransport(reads: [
        .success(handshakeResponse()),
        .success(try serverText(.response(id: .integer(1), result: .object([:])))),
        .success(try serverText(.response(
            id: .integer(3),
            result: .object(["rateLimits": .object([
                "primary": .object(["usedPercent": .number(41)]),
            ])])
        ))),
        .success(try serverText(.response(
            id: .integer(2),
            result: .object(["data": .array([.string("one")])])
        ))),
    ], suspendAfterReadCount: 2)
    let client = makeClient(transport)
    try await client.connect()

    let threads = Task { try await client.readLoadedThreadsSummary() }
    while await transport.writes().count < 4 { await Task.yield() }
    let limits = Task { try await client.readRateLimits() }
    while await transport.writes().count < 5 { await Task.yield() }
    await transport.resumeReads()

    #expect(try await threads.value.count == 1)
    #expect(try await limits.value?.primaryUsedPercent == 41)
}

@Test
func clientUsesOnlyMetadataReadsAndReturnsSafeSummaries() async throws {
    let loadedResult: JSONValue = .object([
        "data": .array([.string("thread-one"), .string("thread-two")]),
        "nextCursor": .null,
    ])
    let rateLimitResult: JSONValue = .object([
        "rateLimits": .object([
            "primary": .object(["usedPercent": .number(25)]),
            "secondary": .null,
        ]),
    ])
    let transport = FakeByteTransport(reads: [
        .success(handshakeResponse()),
        .success(try serverText(.response(id: .integer(1), result: .object([:])))),
        .success(try serverText(.response(id: .integer(2), result: loadedResult))),
        .success(try serverText(.response(id: .integer(3), result: .object([
            "thread": .object([
                "id": .string("thread-one"),
                "status": .object(["type": .string("idle")]),
                "turns": .array([]),
            ]),
        ])))),
        .success(try serverText(.response(id: .integer(4), result: rateLimitResult))),
    ])
    let client = makeClient(transport)
    try await client.connect()

    let loaded = try await client.listLoadedThreadIDs()
    let status = try await client.readLoadedThreadStatus("thread-one")
    let limits = try await client.readRateLimits()

    #expect(loaded == ["thread-one", "thread-two"])
    #expect(status == .idle)
    #expect(limits?.primaryUsedPercent == 25)

    let writes = await transport.writes()
    #expect(try decodedClientMessage(writes[4]) == .request(
        id: .integer(3),
        method: "thread/read",
        params: .object(["threadId": .string("thread-one"), "includeTurns": .bool(false)])
    ))
    #expect(try decodedClientMessage(writes[5]) == .request(
        id: .integer(4),
        method: "account/rateLimits/read",
        params: nil
    ))
}

@Test
func subscriptionIsLimitedToAlreadyLoadedThreadsAndDiscardsResponse() async throws {
    let transport = FakeByteTransport(reads: [
        .success(handshakeResponse()),
        .success(try serverText(.response(id: .integer(1), result: .object([:])))),
        .success(try serverText(.response(
            id: .integer(2),
            result: .object(["data": .array([.string("loaded-thread")])])
        ))),
        .success(try serverText(.response(
            id: .integer(3),
            result: .object(["thread": .object(["turns": .array([.string("discard-me")])])])
        ))),
    ])
    let client = makeClient(transport)
    try await client.connect()
    _ = try await client.listLoadedThreadIDs()

    try await client.subscribeToLoadedThread("loaded-thread")

    let writes = await transport.writes()
    #expect(try decodedClientMessage(writes[4]) == .request(
        id: .integer(3),
        method: "thread/resume",
        params: .object(["threadId": .string("loaded-thread")])
    ))
    await #expect(throws: CodexControlClientError.threadIsNotLoaded) {
        try await client.subscribeToLoadedThread("unknown-thread")
    }
    #expect(await transport.writes().count == 5)
}

@Test
func disconnectUnsubscribesTrackedThreadsBeforeClosingTransport() async throws {
    let transport = FakeByteTransport(reads: [
        .success(handshakeResponse()),
        .success(try serverText(.response(id: .integer(1), result: .object([:])))),
        .success(try serverText(.response(
            id: .integer(2),
            result: .object(["data": .array([.string("loaded-thread")])])
        ))),
        .success(try serverText(.response(id: .integer(3), result: .object([:])))),
    ])
    let client = makeClient(transport)
    try await client.connect()
    _ = try await client.listLoadedThreadIDs()
    try await client.subscribeToLoadedThread("loaded-thread")

    await client.disconnect()

    let writes = await transport.writes()
    #expect(try decodedClientMessage(writes[5]) == .request(
        id: .integer(4),
        method: "thread/unsubscribe",
        params: .object(["threadId": .string("loaded-thread")])
    ))
    #expect(try decodedClientFrame(writes[6]).opcode == .close)
    #expect(await transport.stopCount == 1)
}

@Test(arguments: [
    "turn/start",
    "item/commandExecution/approvalResponse",
    "fs/readFile",
    "process/exec",
])
func mutatingOrSensitiveMethodsAreRejectedBeforeTransport(method: String) async throws {
    let transport = FakeByteTransport(reads: [])
    let client = makeClient(transport)

    await #expect(throws: ReadMethodAllowlistError.methodNotAllowed(method)) {
        _ = try await client.requestReadOnlyForTesting(method: method, params: .object([:]))
    }
    #expect(await transport.writes().isEmpty)
}

@Test
func pingIsAnsweredBeforeThePendingResponseCompletes() async throws {
    let pingPayload = Data("health".utf8)
    let transport = FakeByteTransport(reads: [
        .success(handshakeResponse()),
        .success(serverFrame(opcode: .ping, payload: pingPayload)),
        .success(try serverText(.response(id: .integer(1), result: .object([:])))),
    ])
    let client = makeClient(transport)

    try await client.connect()

    let writes = await transport.writes()
    #expect(writes.count == 4)
    let pong = try decodedClientFrame(writes[2])
    #expect(pong.opcode == .pong)
    #expect(pong.payload == pingPayload)
}

@Test
func processExitClosesTheConnection() async throws {
    let transport = FakeByteTransport(reads: [
        .success(handshakeResponse()),
        .success(nil),
    ])
    let client = makeClient(transport)

    await #expect(throws: CodexControlClientError.transportClosed) {
        try await client.connect()
    }
    #expect(await transport.stopCount == 1)
}

@Test
func reconnectPolicyUsesCappedExponentialBackoffWithJitter() {
    var policy = ReconnectPolicy(baseDelay: 0.5, maximumDelay: 4, jitterFraction: 0.2)

    #expect(policy.nextDelay(randomUnit: 0.5) == 0.5)
    #expect(policy.nextDelay(randomUnit: 0.5) == 1)
    #expect(policy.nextDelay(randomUnit: 1) == 2.4)
    #expect(policy.nextDelay(randomUnit: 0.5) == 4)
    #expect(policy.nextDelay(randomUnit: 0.5) == 4)

    policy.reset()
    #expect(policy.nextDelay(randomUnit: 0) == 0.4)
}

private func makeClient(_ transport: FakeByteTransport) -> CodexControlClient {
    CodexControlClient(
        transport: transport,
        sanitizer: CodexEventSanitizer(salt: Data(repeating: 7, count: 32)),
        webSocketKey: { fixedWebSocketKey }
    )
}

private func handshakeResponse() -> Data {
    Data(
        (
            "HTTP/1.1 101 Switching Protocols\r\n"
                + "Upgrade: websocket\r\n"
                + "Connection: Upgrade\r\n"
                + "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n"
                + "\r\n"
        ).utf8
    )
}

private func serverText(_ message: JSONRPCMessage) throws -> Data {
    serverFrame(opcode: .text, payload: try JSONRPCCodec.encode(message))
}

private func serverFrame(opcode: WebSocketOpcode, payload: Data) -> Data {
    var frame = Data([0x80 | opcode.rawValue])
    if payload.count <= 125 {
        frame.append(UInt8(payload.count))
    } else if payload.count <= Int(UInt16.max) {
        frame.append(126)
        frame.append(contentsOf: UInt16(payload.count).bigEndianBytes)
    } else {
        frame.append(127)
        frame.append(contentsOf: UInt64(payload.count).bigEndianBytes)
    }
    frame.append(payload)
    return frame
}

private func decodedClientMessage(_ frame: Data) throws -> JSONRPCMessage {
    try JSONRPCCodec.decode(decodedClientFrame(frame).payload)
}

private func decodedClientFrame(_ frame: Data) throws -> (opcode: WebSocketOpcode, payload: Data) {
    guard frame.count >= 6,
          let opcode = WebSocketOpcode(rawValue: frame[0] & 0x0f),
          frame[1] & 0x80 != 0
    else {
        throw TestFrameError.invalidFrame
    }
    let shortLength = Int(frame[1] & 0x7f)
    let length: Int
    let maskOffset: Int
    switch shortLength {
    case 126:
        guard frame.count >= 8 else { throw TestFrameError.invalidFrame }
        length = Int(frame[2...3].reduce(UInt16(0)) { ($0 << 8) | UInt16($1) })
        maskOffset = 4
    case 127:
        guard frame.count >= 14 else { throw TestFrameError.invalidFrame }
        let longLength = frame[2...9].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard let exactLength = Int(exactly: longLength) else {
            throw TestFrameError.invalidFrame
        }
        length = exactLength
        maskOffset = 10
    default:
        length = shortLength
        maskOffset = 2
    }
    let payloadOffset = maskOffset + 4
    guard frame.count == payloadOffset + length else {
        throw TestFrameError.invalidFrame
    }
    let mask = Array(frame[maskOffset..<payloadOffset])
    let payload = Data(frame[payloadOffset...].enumerated().map { index, byte in
        byte ^ mask[index % 4]
    })
    return (opcode, payload)
}

private enum TestFrameError: Error {
    case invalidFrame
}

private extension FixedWidthInteger {
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: bigEndian) { Array($0) }
    }
}

private extension JSONValue {
    var object: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }
}

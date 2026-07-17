import Foundation
import Security

public enum CodexControlClientError: Error, Equatable, Sendable {
    case alreadyConnected
    case notConnected
    case invalidHandshake
    case transportClosed
    case unexpectedResponse
    case threadIsNotLoaded
    case serverError(code: Int)
    case randomGenerationFailed
}

public struct CodexLoadedThreadsSummary: Equatable, Sendable {
    public let count: Int

    public init(count: Int) {
        self.count = count
    }
}

public actor CodexControlClient {
    private let transport: any ByteTransport
    private let sanitizer: CodexEventSanitizer
    private let webSocketKey: @Sendable () throws -> String
    private var frameDecoder = WebSocketFrameDecoder()
    private var readerTask: Task<Void, Never>?
    private var readerDemandWaiter: CheckedContinuation<Void, Never>?
    private var pendingResponses: [
        JSONRPCID: AsyncThrowingStream<JSONValue, any Error>.Continuation
    ] = [:]
    private var queuedEvents: [CodexReadEvent] = []
    private var eventWaiters: [CheckedContinuation<CodexReadEvent, any Error>] = []
    private var loadedThreadIDs: Set<String> = []
    private var subscribedThreadIDs: Set<String> = []
    private var nextRequestID = 1
    private var isConnected = false

    public init(transport: any ByteTransport, sanitizer: CodexEventSanitizer) {
        self.transport = transport
        self.sanitizer = sanitizer
        webSocketKey = Self.generateWebSocketKey
    }

    init(
        transport: any ByteTransport,
        sanitizer: CodexEventSanitizer,
        webSocketKey: @escaping @Sendable () throws -> String
    ) {
        self.transport = transport
        self.sanitizer = sanitizer
        self.webSocketKey = webSocketKey
    }

    public func connect() async throws {
        guard !isConnected else { throw CodexControlClientError.alreadyConnected }
        frameDecoder = WebSocketFrameDecoder()
        readerTask?.cancel()
        readerTask = nil
        readerDemandWaiter = nil
        pendingResponses.removeAll(keepingCapacity: true)
        queuedEvents.removeAll(keepingCapacity: true)
        eventWaiters.removeAll(keepingCapacity: true)
        loadedThreadIDs.removeAll(keepingCapacity: true)
        subscribedThreadIDs.removeAll(keepingCapacity: true)
        nextRequestID = 1

        do {
            try await transport.start()
            let key = try webSocketKey()
            try await transport.write(WebSocketHandshake.request(host: "localhost", path: "/", key: key))
            let remainingBytes = try await receiveHandshake(key: key)
            if !remainingBytes.isEmpty {
                try await consumeFrames(remainingBytes)
            }
            startReaderLoop()

            let initializeParams: JSONValue = .object([
                "clientInfo": .object([
                    "name": .string("codex-habitat"),
                    "title": .string("Codex Habitat"),
                    "version": .string("0.1.0"),
                ]),
                "capabilities": .object(["experimentalApi": .bool(false)]),
            ])
            _ = try await sendRequest(method: "initialize", params: initializeParams)
            try await sendNotification(method: "initialized", params: nil)
            isConnected = true
        } catch {
            stopReaderLoop()
            await transport.stop()
            isConnected = false
            if let clientError = error as? CodexControlClientError {
                throw clientError
            }
            throw error
        }
    }

    public func disconnect() async {
        if isConnected {
            for threadID in subscribedThreadIDs.sorted() {
                let id = JSONRPCID.integer(nextRequestID)
                nextRequestID += 1
                try? await send(.request(
                    id: id,
                    method: "thread/unsubscribe",
                    params: .object(["threadId": .string(threadID)])
                ))
            }
            if let close = try? WebSocketFrameEncoder.clientFrame(opcode: .close, payload: Data()) {
                try? await transport.write(close)
            }
        }
        stopReaderLoop()
        await transport.stop()
        failPendingOperations(with: .transportClosed)
        isConnected = false
        loadedThreadIDs.removeAll()
        subscribedThreadIDs.removeAll()
    }

    public func readLoadedThreadsSummary() async throws -> CodexLoadedThreadsSummary {
        CodexLoadedThreadsSummary(count: try await listLoadedThreadIDs().count)
    }

    public func subscribeToLoadedThreads() async throws -> Int {
        let threadIDs = try await listLoadedThreadIDs()
        for threadID in threadIDs {
            try await subscribeToLoadedThread(threadID)
        }
        return threadIDs.count
    }

    public func readLoadedThreadStatuses() async throws -> [SanitizedThreadStatus] {
        let threadIDs = try await listLoadedThreadIDs()
        var statuses: [SanitizedThreadStatus] = []
        statuses.reserveCapacity(threadIDs.count)
        for threadID in threadIDs {
            do {
                if let status = try await readLoadedThreadStatus(threadID) {
                    statuses.append(status)
                }
            } catch CodexControlClientError.threadIsNotLoaded {
                continue
            }
        }
        return statuses
    }

    public func readRateLimits() async throws -> CodexRateLimitUpdate? {
        let result = try await requestReadOnly(
            method: "account/rateLimits/read",
            params: nil
        )
        return sanitizer.sanitize(
            .notification(method: "account/rateLimits/updated", params: result)
        )?.rateLimits
    }

    public func receiveNextEvent() async throws -> CodexReadEvent {
        guard isConnected else { throw CodexControlClientError.notConnected }
        if !queuedEvents.isEmpty {
            return queuedEvents.removeFirst()
        }
        return try await withCheckedThrowingContinuation { continuation in
            eventWaiters.append(continuation)
            signalReaderDemand()
        }
    }

    func listLoadedThreadIDs() async throws -> [String] {
        let result = try await requestReadOnly(
            method: "thread/loaded/list",
            params: .object([:])
        )
        guard case let .object(object) = result,
              case let .array(values)? = object["data"]
        else {
            throw CodexControlClientError.unexpectedResponse
        }
        let ids = values.compactMap(\.stringValue)
        guard ids.count == values.count else {
            throw CodexControlClientError.unexpectedResponse
        }
        loadedThreadIDs = Set(ids)
        return ids
    }

    func readLoadedThreadStatus(_ threadID: String) async throws -> SanitizedThreadStatus? {
        do {
            let result = try await requestReadOnly(
                method: "thread/read",
                params: .object([
                    "threadId": .string(threadID),
                    "includeTurns": .bool(false),
                ])
            )
            guard case let .object(object) = result,
                  case let .object(thread)? = object["thread"]
            else {
                throw CodexControlClientError.unexpectedResponse
            }
            let status = thread["status"]?.stringValue
                ?? thread["status"]?.objectValue?["type"]?.stringValue
            return status.flatMap(SanitizedThreadStatus.init(rawValue:))
        } catch ReadMethodAllowlistError.threadIsNotLoaded {
            throw CodexControlClientError.threadIsNotLoaded
        }
    }

    func subscribeToLoadedThread(_ threadID: String) async throws {
        do {
            // Resume is the current protocol's subscription primitive. Only an already-loaded
            // thread ID is sent, and its potentially rich response is discarded here.
            _ = try await requestReadOnly(
                method: "thread/resume",
                params: .object(["threadId": .string(threadID)])
            )
            subscribedThreadIDs.insert(threadID)
        } catch ReadMethodAllowlistError.threadIsNotLoaded {
            throw CodexControlClientError.threadIsNotLoaded
        }
    }

    func requestReadOnlyForTesting(
        method: String,
        params: JSONValue?
    ) async throws -> JSONValue {
        try await requestReadOnly(method: method, params: params)
    }

    private func requestReadOnly(method: String, params: JSONValue?) async throws -> JSONValue {
        try ReadMethodAllowlist.validate(
            method: method,
            params: params,
            loadedThreadIDs: loadedThreadIDs
        )
        guard isConnected else { throw CodexControlClientError.notConnected }
        return try await sendRequest(method: method, params: params)
    }

    private func sendRequest(method: String, params: JSONValue?) async throws -> JSONValue {
        let id = JSONRPCID.integer(nextRequestID)
        nextRequestID += 1
        let pair = AsyncThrowingStream<JSONValue, any Error>.makeStream()
        pendingResponses[id] = pair.continuation
        signalReaderDemand()
        do {
            try await send(.request(id: id, method: method, params: params))
        } catch {
            pendingResponses.removeValue(forKey: id)
            pair.continuation.finish(throwing: sanitizedConnectionError(error))
            throw sanitizedConnectionError(error)
        }

        var iterator = pair.stream.makeAsyncIterator()
        guard let result = try await iterator.next() else {
            throw CodexControlClientError.transportClosed
        }
        return result
    }

    private func sendNotification(method: String, params: JSONValue?) async throws {
        try await send(.notification(method: method, params: params))
    }

    private func send(_ message: JSONRPCMessage) async throws {
        let payload = try JSONRPCCodec.encode(message)
        let frame = try WebSocketFrameEncoder.clientFrame(opcode: .text, payload: payload)
        try await transport.write(frame)
    }

    private func consumeFrames(_ data: Data) async throws {
        for event in try frameDecoder.append(data) {
            switch event {
            case let .text(payload):
                route(try JSONRPCCodec.decode(payload))
            case let .pongRequired(payload):
                let pong = try WebSocketFrameEncoder.clientFrame(opcode: .pong, payload: payload)
                try await transport.write(pong)
            case .closed:
                throw CodexControlClientError.transportClosed
            case .binary, .pong:
                continue
            }
        }
    }

    private func route(_ message: JSONRPCMessage) {
        switch message {
        case let .response(id, result):
            guard let continuation = pendingResponses.removeValue(forKey: id) else { return }
            continuation.yield(result)
            continuation.finish()
        case let .error(id, error):
            guard let continuation = pendingResponses.removeValue(forKey: id) else { return }
            continuation.finish(throwing: CodexControlClientError.serverError(code: error.code))
        case .notification, .request:
            guard let event = sanitizer.sanitize(message) else { return }
            if eventWaiters.isEmpty {
                queuedEvents.append(event)
            } else {
                eventWaiters.removeFirst().resume(returning: event)
            }
        }
    }

    private func startReaderLoop() {
        readerTask = Task { [weak self] in
            await self?.runReaderLoop()
        }
    }

    private func stopReaderLoop() {
        readerTask?.cancel()
        readerTask = nil
        readerDemandWaiter?.resume()
        readerDemandWaiter = nil
    }

    private func runReaderLoop() async {
        do {
            while !Task.isCancelled {
                await waitForReaderDemand()
                guard !Task.isCancelled else { return }
                guard let data = try await transport.read() else {
                    throw CodexControlClientError.transportClosed
                }
                try await consumeFrames(data)
            }
        } catch {
            let safeError = sanitizedConnectionError(error)
            isConnected = false
            failPendingOperations(with: safeError)
        }
    }

    private func waitForReaderDemand() async {
        guard pendingResponses.isEmpty, eventWaiters.isEmpty else { return }
        await withCheckedContinuation { continuation in
            readerDemandWaiter = continuation
        }
    }

    private func signalReaderDemand() {
        readerDemandWaiter?.resume()
        readerDemandWaiter = nil
    }

    private func failPendingOperations(with error: CodexControlClientError) {
        let responses = pendingResponses.values
        pendingResponses.removeAll()
        for response in responses {
            response.finish(throwing: error)
        }
        let waiters = eventWaiters
        eventWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(throwing: error)
        }
    }

    private func sanitizedConnectionError(_ error: any Error) -> CodexControlClientError {
        if let error = error as? CodexControlClientError {
            return error
        }
        return .transportClosed
    }

    private func receiveHandshake(key: String) async throws -> Data {
        let marker = Data("\r\n\r\n".utf8)
        var response = Data()
        while response.range(of: marker) == nil {
            guard let data = try await transport.read() else {
                throw CodexControlClientError.transportClosed
            }
            response.append(data)
        }
        guard let markerRange = response.range(of: marker) else {
            throw CodexControlClientError.invalidHandshake
        }
        let headerEnd = markerRange.upperBound
        let headers = response.subdata(in: 0..<headerEnd)
        guard try WebSocketHandshake.validate(response: headers, key: key) else {
            throw CodexControlClientError.invalidHandshake
        }
        return response.subdata(in: headerEnd..<response.count)
    }

    private static func generateWebSocketKey() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CodexControlClientError.randomGenerationFailed
        }
        return Data(bytes).base64EncodedString()
    }
}

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
}

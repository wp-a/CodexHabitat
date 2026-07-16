import Foundation

public protocol ByteTransport: Sendable {
    func start() async throws
    func write(_ data: Data) async throws
    func read() async throws -> Data?
    func stop() async
}

public enum ProcessTransportError: Error, Equatable, Sendable {
    case alreadyStarted
    case notStarted
    case exited(Int32)
}

public actor ProcessTransport: ByteTransport {
    private let executableURL: URL
    private let arguments: [String]
    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private var bufferedReads: [Data] = []
    private var waitingReaders: [CheckedContinuation<Data?, any Error>] = []
    private var terminalError: ProcessTransportError?
    private var reachedEnd = false

    public init(
        executableURL: URL = URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [String] = ["codex", "app-server", "proxy"]
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
    }

    public func start() async throws {
        guard process == nil else { throw ProcessTransportError.alreadyStarted }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorPipe

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { await self?.receive(data) }
        }
        // Drain diagnostics without publishing command output or local paths.
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { await self?.processExited(status: status) }
        }

        do {
            try process.run()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }

        self.process = process
        inputHandle = input.fileHandleForWriting
        outputHandle = output.fileHandleForReading
        errorHandle = errorPipe.fileHandleForReading
        bufferedReads.removeAll(keepingCapacity: true)
        waitingReaders.removeAll(keepingCapacity: true)
        terminalError = nil
        reachedEnd = false
    }

    public func write(_ data: Data) async throws {
        guard let inputHandle else { throw ProcessTransportError.notStarted }
        try inputHandle.write(contentsOf: data)
    }

    public func read() async throws -> Data? {
        if !bufferedReads.isEmpty {
            return bufferedReads.removeFirst()
        }
        if let terminalError {
            throw terminalError
        }
        if reachedEnd {
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            waitingReaders.append(continuation)
        }
    }

    public func stop() async {
        outputHandle?.readabilityHandler = nil
        errorHandle?.readabilityHandler = nil
        try? inputHandle?.close()
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        inputHandle = nil
        outputHandle = nil
        errorHandle = nil
        finish(with: nil)
    }

    private func receive(_ data: Data) {
        guard !reachedEnd, terminalError == nil else { return }
        guard !data.isEmpty else {
            finish(with: nil)
            return
        }
        if waitingReaders.isEmpty {
            bufferedReads.append(data)
        } else {
            waitingReaders.removeFirst().resume(returning: data)
        }
    }

    private func processExited(status: Int32) {
        if status == 0 {
            finish(with: nil)
        } else {
            finish(with: .exited(status))
        }
    }

    private func finish(with error: ProcessTransportError?) {
        guard !reachedEnd, terminalError == nil else { return }
        terminalError = error
        reachedEnd = error == nil
        let readers = waitingReaders
        waitingReaders.removeAll()
        for reader in readers {
            if let error {
                reader.resume(throwing: error)
            } else {
                reader.resume(returning: nil)
            }
        }
    }
}

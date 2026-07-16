import CodexConnector
import Foundation

actor FakeByteTransport: ByteTransport {
    private var reads: [Result<Data?, any Error>]
    private var recordedWrites: [Data] = []
    private let suspendAfterReadCount: Int?
    private var completedReadCount = 0
    private var readsSuspended: Bool
    private var readWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(reads: [Result<Data?, any Error>], suspendAfterReadCount: Int? = nil) {
        self.reads = reads
        self.suspendAfterReadCount = suspendAfterReadCount
        readsSuspended = suspendAfterReadCount != nil
    }

    func start() async throws {
        startCount += 1
    }

    func write(_ data: Data) async throws {
        recordedWrites.append(data)
    }

    func read() async throws -> Data? {
        if let suspendAfterReadCount,
           completedReadCount >= suspendAfterReadCount,
           readsSuspended {
            await withCheckedContinuation { continuation in
                readWaiters.append(continuation)
            }
        }
        guard !reads.isEmpty else { return nil }
        completedReadCount += 1
        return try reads.removeFirst().get()
    }

    func stop() async {
        stopCount += 1
    }

    func writes() -> [Data] {
        recordedWrites
    }

    func resumeReads() {
        readsSuspended = false
        let waiters = readWaiters
        readWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

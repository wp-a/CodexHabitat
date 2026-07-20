import Darwin
import Foundation

protocol ThemeProcessLaunching: AnyObject, Sendable {
    func launch(executableURL: URL, arguments: [String]) throws -> Int32
    func terminateLaunchedProcess(pid: Int32) -> Bool
    func releaseLaunchedProcess(pid: Int32)
}

protocol ThemeProcessSignaling: AnyObject, Sendable {
    func terminate(process: ProcessIdentity) -> Bool
}

protocol LoopbackPortAllocating: Sendable {
    func allocate() throws -> UInt16
}

enum ThemeSessionStatus: Equatable {
    case inactive
    case active(SessionRecord)
    case stale
}

enum ThemeSessionError: Error, Equatable {
    case authorizationRequired
    case sessionAlreadyActive
    case portOutsideAllowedRange(UInt16)
    case processInspectionFailed
    case unexpectedExecutable
    case unexpectedProcessAncestry
    case noActiveSession
    case processIdentityChanged
    case terminationFailed
}

protocol ThemeSessionManaging: AnyObject, Sendable {
    func start(bundleURL: URL, authorized: Bool) throws -> SessionRecord
    func status() -> ThemeSessionStatus
    func stop() throws
}

final class ThemeSession: ThemeSessionManaging, @unchecked Sendable {
    private let verifier: any CodexBundleVerifying
    private let launcher: any ThemeProcessLaunching
    private let processInspector: any CodexProcessInspecting
    private let signaler: any ThemeProcessSignaling
    private let portAllocator: any LoopbackPortAllocating
    private let recordStore: SessionRecordStore
    private let ownerPID: Int32

    init(
        verifier: any CodexBundleVerifying,
        launcher: any ThemeProcessLaunching,
        processInspector: any CodexProcessInspecting,
        signaler: any ThemeProcessSignaling,
        portAllocator: any LoopbackPortAllocating,
        recordStore: SessionRecordStore,
        ownerPID: Int32
    ) {
        self.verifier = verifier
        self.launcher = launcher
        self.processInspector = processInspector
        self.signaler = signaler
        self.portAllocator = portAllocator
        self.recordStore = recordStore
        self.ownerPID = ownerPID
    }

    func start(bundleURL: URL, authorized: Bool) throws -> SessionRecord {
        guard authorized else { throw ThemeSessionError.authorizationRequired }
        if let existing = try recordStore.load() {
            if let current = processInspector.identity(for: existing.process.pid),
               current.matchesPersistentIdentity(existing.process) {
                throw ThemeSessionError.sessionAlreadyActive
            }
            try recordStore.clear()
        }

        let bundle = try verifier.verify(bundleURL)
        let port = try portAllocator.allocate()
        guard (49_152...65_535).contains(Int(port)) else {
            throw ThemeSessionError.portOutsideAllowedRange(port)
        }
        let pid = try launcher.launch(
            executableURL: bundle.executableURL,
            arguments: [
                "--remote-debugging-address=127.0.0.1",
                "--remote-debugging-port=\(port)",
                "--remote-allow-origins=http://127.0.0.1:\(port)",
            ]
        )
        defer { launcher.releaseLaunchedProcess(pid: pid) }
        guard let identity = processInspector.identity(for: pid) else {
            _ = launcher.terminateLaunchedProcess(pid: pid)
            throw ThemeSessionError.processInspectionFailed
        }
        guard identity.executableURL.standardizedFileURL.resolvingSymlinksInPath()
            == bundle.executableURL.standardizedFileURL.resolvingSymlinksInPath()
        else {
            _ = launcher.terminateLaunchedProcess(pid: pid)
            throw ThemeSessionError.unexpectedExecutable
        }
        guard processInspector.isDescendant(pid, of: ownerPID) else {
            if !signaler.terminate(process: identity) {
                _ = launcher.terminateLaunchedProcess(pid: pid)
            }
            throw ThemeSessionError.unexpectedProcessAncestry
        }

        let record = SessionRecord(
            bundleURL: bundle.bundleURL,
            bundleIdentifier: bundle.bundleIdentifier,
            bundleVersion: bundle.version,
            port: port,
            process: identity
        )
        do {
            try recordStore.save(record)
        } catch {
            if let current = processInspector.identity(for: pid),
               current.matchesPersistentIdentity(identity) {
                if !signaler.terminate(process: current) {
                    _ = launcher.terminateLaunchedProcess(pid: pid)
                }
            } else {
                _ = launcher.terminateLaunchedProcess(pid: pid)
            }
            throw error
        }
        return record
    }

    func status() -> ThemeSessionStatus {
        let record: SessionRecord
        do {
            guard let loaded = try recordStore.load() else { return .inactive }
            record = loaded
        } catch {
            return .stale
        }
        guard let current = processInspector.identity(for: record.process.pid),
              current.matchesPersistentIdentity(record.process)
        else { return .stale }
        return .active(record)
    }

    func stop() throws {
        guard let record = try recordStore.load() else {
            throw ThemeSessionError.noActiveSession
        }
        guard let current = processInspector.identity(for: record.process.pid),
              current.matchesPersistentIdentity(record.process)
        else {
            throw ThemeSessionError.processIdentityChanged
        }
        guard signaler.terminate(process: current) else {
            throw ThemeSessionError.terminationFailed
        }
        try recordStore.clear()
    }
}

final class LiveThemeProcessLauncher: ThemeProcessLaunching, @unchecked Sendable {
    private let lock = NSLock()
    private var launchedProcesses: [Int32: Process] = [:]

    func launch(executableURL: URL, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        let pid = process.processIdentifier
        lock.withLock { launchedProcesses[pid] = process }
        return pid
    }

    func terminateLaunchedProcess(pid: Int32) -> Bool {
        let process = lock.withLock { launchedProcesses[pid] }
        guard let process else { return false }
        guard process.isRunning else { return true }
        process.terminate()
        for _ in 0..<40 {
            guard process.isRunning else { break }
            usleep(50_000)
        }
        if process.isRunning {
            _ = Darwin.kill(pid, SIGKILL)
        }
        for _ in 0..<40 {
            guard process.isRunning else { break }
            usleep(50_000)
        }
        return !process.isRunning
    }

    func releaseLaunchedProcess(pid: Int32) {
        _ = lock.withLock { launchedProcesses.removeValue(forKey: pid) }
    }
}

final class LiveThemeProcessSignaler: ThemeProcessSignaling, @unchecked Sendable {
    private let inspector = CodexProcessInspector()

    func terminate(process: ProcessIdentity) -> Bool {
        guard let current = inspector.identity(for: process.pid),
              current.matchesPersistentIdentity(process),
              Darwin.kill(process.pid, SIGTERM) == 0
        else {
            return false
        }
        for _ in 0..<40 {
            usleep(50_000)
            guard let remaining = inspector.identity(for: process.pid),
                  remaining.matchesPersistentIdentity(process)
            else {
                return true
            }
        }
        return false
    }
}

struct LiveLoopbackPortAllocator: LoopbackPortAllocating {
    enum AllocationError: Error {
        case unavailable
    }

    func allocate() throws -> UInt16 {
        for _ in 0..<64 {
            let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            guard descriptor >= 0 else { continue }
            defer { Darwin.close(descriptor) }
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = UInt16.random(in: 49_152...65_535).bigEndian
            address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    Darwin.bind(
                        descriptor,
                        socketAddress,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
            if result == 0 {
                return UInt16(bigEndian: address.sin_port)
            }
        }
        throw AllocationError.unavailable
    }
}

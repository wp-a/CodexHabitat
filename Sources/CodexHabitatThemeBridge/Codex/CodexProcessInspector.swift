import Darwin
import Foundation

struct ProcessIdentity: Codable, Equatable, Sendable {
    let pid: Int32
    let parentPID: Int32
    let executableURL: URL
    let startTimeMicroseconds: UInt64

    func matchesPersistentIdentity(_ other: ProcessIdentity) -> Bool {
        pid == other.pid
            && startTimeMicroseconds == other.startTimeMicroseconds
            && executableURL.standardizedFileURL.resolvingSymlinksInPath()
                == other.executableURL.standardizedFileURL.resolvingSymlinksInPath()
    }
}

protocol CodexProcessInspecting: AnyObject {
    func identity(for pid: Int32) -> ProcessIdentity?
    func isDescendant(_ pid: Int32, of ancestorPID: Int32) -> Bool
}

final class CodexProcessInspector: CodexProcessInspecting {
    private let lookup: (Int32) -> ProcessIdentity?

    init(lookup: @escaping (Int32) -> ProcessIdentity? = CodexProcessInspector.liveIdentity) {
        self.lookup = lookup
    }

    func identity(for pid: Int32) -> ProcessIdentity? {
        lookup(pid)
    }

    func isDescendant(_ pid: Int32, of ancestorPID: Int32) -> Bool {
        var current = pid
        var visited: Set<Int32> = []
        for _ in 0..<64 {
            if current == ancestorPID { return true }
            guard current > 1,
                  visited.insert(current).inserted,
                  let identity = lookup(current)
            else {
                return false
            }
            current = identity.parentPID
        }
        return false
    }

    private static func liveIdentity(_ pid: Int32) -> ProcessIdentity? {
        var info = proc_bsdinfo()
        let infoSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, infoSize) == infoSize else {
            return nil
        }
        let bufferSize = Int(MAXPATHLEN * 4)
        var pathBuffer = [CChar](repeating: 0, count: bufferSize)
        guard proc_pidpath(pid, &pathBuffer, UInt32(bufferSize)) > 0 else {
            return nil
        }
        let seconds = UInt64(info.pbi_start_tvsec)
        let microseconds = UInt64(info.pbi_start_tvusec)
        let pathBytes = pathBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return ProcessIdentity(
            pid: pid,
            parentPID: Int32(info.pbi_ppid),
            executableURL: URL(fileURLWithPath: String(decoding: pathBytes, as: UTF8.self))
                .standardizedFileURL.resolvingSymlinksInPath(),
            startTimeMicroseconds: seconds * 1_000_000 + microseconds
        )
    }
}

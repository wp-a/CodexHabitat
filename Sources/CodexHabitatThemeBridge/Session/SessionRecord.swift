import Foundation

struct SessionRecord: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let bundleURL: URL
    let bundleIdentifier: String
    let bundleVersion: String
    let port: UInt16
    let process: ProcessIdentity
    let createdAt: Date

    init(
        schemaVersion: Int = 1,
        bundleURL: URL,
        bundleIdentifier: String,
        bundleVersion: String,
        port: UInt16,
        process: ProcessIdentity,
        createdAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.bundleVersion = bundleVersion
        self.port = port
        self.process = process
        self.createdAt = createdAt
    }
}

enum SessionRecordError: Error, Equatable {
    case unsafeRoot
    case unsafeRecord
    case unsupportedSchema
}

struct SessionRecordStore {
    let root: URL
    let recordURL: URL

    private let fileManager: FileManager

    init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        recordURL = root.appending(path: "session.json")
        self.fileManager = fileManager
    }

    func save(_ record: SessionRecord) throws {
        try prepareRoot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(to: recordURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: recordURL.path
        )
    }

    func load() throws -> SessionRecord? {
        guard fileManager.fileExists(atPath: recordURL.path) else { return nil }
        guard isSafeDirectory(root, permissions: 0o700),
              isSafeFile(recordURL, permissions: 0o600)
        else {
            throw SessionRecordError.unsafeRecord
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(
            SessionRecord.self,
            from: Data(contentsOf: recordURL, options: .mappedIfSafe)
        )
        guard record.schemaVersion == 1 else {
            throw SessionRecordError.unsupportedSchema
        }
        return record
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: recordURL.path) else { return }
        try fileManager.removeItem(at: recordURL)
    }

    private func prepareRoot() throws {
        if fileManager.fileExists(atPath: root.path) {
            guard isSafeDirectory(root, permissions: nil) else {
                throw SessionRecordError.unsafeRoot
            }
        } else {
            try fileManager.createDirectory(
                at: root,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
    }

    private func isSafeDirectory(_ url: URL, permissions: Int?) -> Bool {
        guard let values = try? url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ), values.isDirectory == true, values.isSymbolicLink != true,
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        else {
            return false
        }
        guard let permissions else { return true }
        return (attributes[.posixPermissions] as? NSNumber)?.intValue == permissions
    }

    private func isSafeFile(_ url: URL, permissions: Int) -> Bool {
        guard let values = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        ), values.isRegularFile == true, values.isSymbolicLink != true,
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        else {
            return false
        }
        return (attributes[.posixPermissions] as? NSNumber)?.intValue == permissions
    }
}

import Foundation

public enum DiagnosticStorageError: Error, Equatable, Sendable {
    case unsupportedSchema
    case documentTooLarge
    case unsafeSymbolicLink
    case unsafeStorageNode
}

public actor DiagnosticStore {
    private static let schemaVersion = 1
    private static let maximumDocumentBytes = 2 * 1024 * 1024

    private let root: URL
    private let eventsURL: URL
    private let fileManager: FileManager
    private let retention: TimeInterval
    private let maximumEventCount: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        root: URL,
        fileManager: FileManager = .default,
        retention: TimeInterval = 7 * 24 * 60 * 60,
        maximumEventCount: Int = 2_000
    ) {
        self.root = root
        eventsURL = root.appending(path: "events.json")
        self.fileManager = fileManager
        self.retention = max(0, retention)
        self.maximumEventCount = max(1, maximumEventCount)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
    }

    public func record(_ event: DiagnosticEvent, now: Date = Date()) throws {
        var current = try load()
        current.append(event)
        current = normalized(current, now: now)
        try save(current)
    }

    public func events(now: Date = Date()) throws -> [DiagnosticEvent] {
        let loaded = try load()
        let current = normalized(loaded, now: now)
        if current != loaded {
            try save(current)
        }
        return current
    }

    public func clear() throws {
        try prepareRoot()
        guard let attributes = try DiagnosticFileSafety.attributesIfPresent(
            at: eventsURL,
            fileManager: fileManager
        ) else { return }
        try DiagnosticFileSafety.rejectSymbolicLink(attributes)
        try fileManager.removeItem(at: eventsURL)
    }

    private func normalized(_ events: [DiagnosticEvent], now: Date) -> [DiagnosticEvent] {
        let threshold = now.addingTimeInterval(-retention)
        let futureLimit = now.addingTimeInterval(5 * 60)
        let retained = events
            .filter { $0.timestamp >= threshold && $0.timestamp <= futureLimit }
            .sorted(by: DiagnosticEvent.ordered)
        return Array(retained.suffix(maximumEventCount))
    }

    private func load() throws -> [DiagnosticEvent] {
        try prepareRoot()
        guard let attributes = try DiagnosticFileSafety.attributesIfPresent(
            at: eventsURL,
            fileManager: fileManager
        ) else { return [] }
        try DiagnosticFileSafety.rejectSymbolicLink(attributes)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw DiagnosticStorageError.unsafeStorageNode
        }
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard size <= Self.maximumDocumentBytes else {
            throw DiagnosticStorageError.documentTooLarge
        }
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: eventsURL.path
        )
        let document = try decoder.decode(
            DiagnosticDocument.self,
            from: Data(contentsOf: eventsURL)
        )
        guard document.schemaVersion == Self.schemaVersion else {
            throw DiagnosticStorageError.unsupportedSchema
        }
        return document.events
    }

    private func save(_ events: [DiagnosticEvent]) throws {
        try prepareRoot()
        if let attributes = try DiagnosticFileSafety.attributesIfPresent(
            at: eventsURL,
            fileManager: fileManager
        ) {
            try DiagnosticFileSafety.rejectSymbolicLink(attributes)
        }
        let data = try encoder.encode(DiagnosticDocument(
            schemaVersion: Self.schemaVersion,
            events: events
        ))
        guard data.count <= Self.maximumDocumentBytes else {
            throw DiagnosticStorageError.documentTooLarge
        }
        try data.write(to: eventsURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: eventsURL.path
        )
    }

    private func prepareRoot() throws {
        if let attributes = try DiagnosticFileSafety.attributesIfPresent(
            at: root,
            fileManager: fileManager
        ) {
            try DiagnosticFileSafety.rejectSymbolicLink(attributes)
            guard attributes[.type] as? FileAttributeType == .typeDirectory else {
                throw DiagnosticStorageError.unsafeStorageNode
            }
        } else {
            try fileManager.createDirectory(
                at: root,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: root.path
        )
    }

}

public struct DiagnosticMaintenance {
    private let root: URL
    private let fileManager: FileManager

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    @discardableResult
    public func clearPreviewCache() throws -> Int {
        let cacheParent = root.appending(path: "Cache", directoryHint: .isDirectory)
        let previewCache = cacheParent.appending(
            path: "Previews",
            directoryHint: .isDirectory
        )
        for directory in [root, cacheParent, previewCache] {
            if let attributes = try DiagnosticFileSafety.attributesIfPresent(
                at: directory,
                fileManager: fileManager
            ) {
                guard attributes[.type] as? FileAttributeType == .typeDirectory else {
                    throw attributes[.type] as? FileAttributeType == .typeSymbolicLink
                        ? DiagnosticStorageError.unsafeSymbolicLink
                        : DiagnosticStorageError.unsafeStorageNode
                }
            } else {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: false,
                    attributes: [.posixPermissions: 0o700]
                )
            }
            try fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path
            )
        }
        let contents = try fileManager.contentsOfDirectory(
            at: previewCache,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: []
        )
        for item in contents {
            try fileManager.removeItem(at: item)
        }
        return contents.count
    }
}

private struct DiagnosticDocument: Codable {
    let schemaVersion: Int
    let events: [DiagnosticEvent]
}

enum DiagnosticFileSafety {
    static func attributesIfPresent(
        at url: URL,
        fileManager: FileManager
    ) throws -> [FileAttributeKey: Any]? {
        do {
            return try fileManager.attributesOfItem(atPath: url.path)
        } catch let error as CocoaError where [
            .fileNoSuchFile,
            .fileReadNoSuchFile,
        ].contains(error.code) {
            return nil
        }
    }

    static func rejectSymbolicLink(
        _ attributes: [FileAttributeKey: Any]
    ) throws {
        if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
            throw DiagnosticStorageError.unsafeSymbolicLink
        }
    }
}

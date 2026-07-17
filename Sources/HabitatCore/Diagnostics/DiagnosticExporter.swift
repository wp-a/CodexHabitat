import Foundation

public struct DiagnosticExporter: Sendable {
    public init() {}

    public func data<Events: Sequence>(
        events: Events,
        exportedAt: Date = Date()
    ) throws -> Data where Events.Element == DiagnosticEvent {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(DiagnosticExportDocument(
            schemaVersion: 1,
            exportedAt: exportedAt,
            events: events.sorted(by: DiagnosticEvent.ordered),
            recovery: DiagnosticRecoveryExport(
                title: DiagnosticRecovery.officialAppearanceTitle,
                executable: DiagnosticRecovery.themeBridgeExecutable,
                arguments: DiagnosticRecovery.themeBridgeArguments
            )
        ))
    }

    public func export<Events: Sequence>(
        events: Events,
        exportedAt: Date = Date(),
        to destination: URL
    ) throws where Events.Element == DiagnosticEvent {
        let fileManager = FileManager.default
        if let attributes = try DiagnosticFileSafety.attributesIfPresent(
            at: destination,
            fileManager: fileManager
        ) {
            try DiagnosticFileSafety.rejectSymbolicLink(attributes)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw DiagnosticStorageError.unsafeStorageNode
            }
        }
        try data(events: events, exportedAt: exportedAt)
            .write(to: destination, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
    }
}

private struct DiagnosticExportDocument: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let events: [DiagnosticEvent]
    let recovery: DiagnosticRecoveryExport
}

private struct DiagnosticRecoveryExport: Codable {
    let title: String
    let executable: String
    let arguments: [String]
}

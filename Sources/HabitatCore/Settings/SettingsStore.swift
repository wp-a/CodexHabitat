import Foundation

public actor SettingsStore {
    private let directories: AppDirectories
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(root: URL, fileManager: FileManager = .default) {
        directories = AppDirectories(root: root)
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    public func load() throws -> HabitatSettings {
        try directories.prepare(fileManager: fileManager)
        guard fileManager.fileExists(atPath: directories.settings.path) else {
            return .default
        }
        let data = try Data(contentsOf: directories.settings)
        return try decoder.decode(HabitatSettings.self, from: data)
    }

    public func save(_ settings: HabitatSettings) throws {
        try directories.prepare(fileManager: fileManager)
        let data = try encoder.encode(settings)
        try data.write(to: directories.settings, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: directories.settings.path
        )
    }
}

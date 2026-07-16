import Foundation

public struct PetLibrary {
    public let root: URL
    private let fileManager: FileManager
    private let validator: PetValidator

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
        validator = PetValidator(fileManager: fileManager)
    }

    public static func petRoot(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        if let configured = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
                .appending(path: "pets", directoryHint: .isDirectory)
        }
        return homeDirectory.appending(path: ".codex/pets", directoryHint: .isDirectory)
    }

    public func discover() throws -> [PetLibraryEntry] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            return []
        }
        let directories = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        var entries = directories.map(validator.validate(directory:))
        var seenValidIDs: Set<String> = []
        for index in entries.indices where entries[index].status == .valid {
            guard let id = entries[index].manifest?.id else { continue }
            if seenValidIDs.insert(id).inserted {
                continue
            }
            entries[index] = entries[index].replacingStatus(.duplicateID)
        }
        return entries
    }
}

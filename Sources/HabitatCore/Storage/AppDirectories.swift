import Foundation

public struct AppDirectories: Equatable, Sendable {
    public let root: URL
    public let settings: URL
    public let pets: URL
    public let themes: URL
    public let previewCache: URL
    public let diagnostics: URL

    public init(root: URL) {
        self.root = root
        settings = root.appending(path: "Settings.json")
        pets = root.appending(path: "Library/Pets", directoryHint: .isDirectory)
        themes = root.appending(path: "Library/Themes", directoryHint: .isDirectory)
        previewCache = root.appending(path: "Cache/Previews", directoryHint: .isDirectory)
        diagnostics = root.appending(path: "Diagnostics", directoryHint: .isDirectory)
    }

    public func prepare(fileManager: FileManager = .default) throws {
        let directories = [root, pets, themes, previewCache, diagnostics]
        for directory in directories {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path
            )
        }
    }
}

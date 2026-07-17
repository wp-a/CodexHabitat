import Foundation

public struct InstalledPackageLibrary {
    public let root: URL
    public let runtimeVersion: String

    private let fileManager: FileManager

    public init(
        root: URL,
        runtimeVersion: String,
        fileManager: FileManager = .default
    ) {
        self.root = root
        self.runtimeVersion = runtimeVersion
        self.fileManager = fileManager
    }

    public func currentPackages() -> [InstalledPackage] {
        let packageDirectories = safeDirectories(in: root)
        return packageDirectories.compactMap(currentPackage(in:)).sorted { $0.id < $1.id }
    }

    private func currentPackage(in packageDirectory: URL) -> InstalledPackage? {
        let candidates: [(SemanticVersion, HabitatManifest, URL)] = safeDirectories(
            in: packageDirectory
        ).compactMap { versionDirectory in
            let manifestURL = versionDirectory.appending(path: "habitat.json")
            guard isRegularFile(manifestURL),
                  let data = try? Data(contentsOf: manifestURL, options: .mappedIfSafe),
                  let manifest = try? ManifestDecoder(runtimeVersion: runtimeVersion).decode(data),
                  manifest.id == packageDirectory.lastPathComponent,
                  manifest.version == versionDirectory.lastPathComponent,
                  let semanticVersion = SemanticVersion(manifest.version)
            else {
                return nil
            }
            return (semanticVersion, manifest, versionDirectory)
        }
        guard let selected = candidates.max(by: { $0.0 < $1.0 }) else { return nil }
        return InstalledPackage(
            id: selected.1.id,
            version: selected.1.version,
            url: selected.2,
            manifest: selected.1
        )
    }

    private func safeDirectories(in directory: URL) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.filter { url in
            guard let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            ) else {
                return false
            }
            return values.isDirectory == true && values.isSymbolicLink != true
        }
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        ) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }
}

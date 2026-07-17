import Foundation
import ZIPFoundation

public enum PackageLibraryError: Error, Equatable, Sendable {
    case packageNotFound
    case unsafePackage
    case unsafeDestination
}

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

    public func uninstall(packageID: String) throws {
        guard let package = currentPackages().first(where: { $0.id == packageID }) else {
            throw PackageLibraryError.packageNotFound
        }
        let packageRoot = package.url.deletingLastPathComponent()
        guard isContained(packageRoot, in: root),
              !isSymbolicLink(packageRoot)
        else {
            throw PackageLibraryError.unsafePackage
        }
        try fileManager.removeItem(at: packageRoot)
    }

    public func export(packageID: String, to destination: URL) throws {
        guard let package = currentPackages().first(where: { $0.id == packageID }) else {
            throw PackageLibraryError.packageNotFound
        }
        guard isContained(package.url, in: root),
              !isSymbolicLink(package.url),
              !isSymbolicLink(destination)
        else {
            throw PackageLibraryError.unsafeDestination
        }
        if fileManager.fileExists(atPath: destination.path), !isRegularFile(destination) {
            throw PackageLibraryError.unsafeDestination
        }

        let temporary = destination.deletingLastPathComponent().appending(
            path: ".habitat-export-\(UUID().uuidString).habitat-pack"
        )
        defer {
            if fileManager.fileExists(atPath: temporary.path) {
                try? fileManager.removeItem(at: temporary)
            }
        }
        let archive = try Archive(url: temporary, accessMode: .create)
        for item in try exportItems(in: package.url) {
            try archive.addEntry(
                with: item.relativePath,
                fileURL: item.url,
                compressionMethod: item.isDirectory ? .none : .deflate
            )
        }
        _ = try ArchiveInspector().inspect(temporary)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
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

    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private func isContained(_ candidate: URL, in root: URL) -> Bool {
        candidate.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/")
    }

    private func exportItems(
        in packageURL: URL
    ) throws -> [(url: URL, relativePath: String, isDirectory: Bool)] {
        guard let enumerator = fileManager.enumerator(
            at: packageURL,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: [.skipsHiddenFiles]
        ) else {
            throw PackageLibraryError.unsafePackage
        }
        var result: [(URL, String, Bool)] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ])
            guard values.isSymbolicLink != true,
                  values.isDirectory == true || values.isRegularFile == true,
                  isContained(url, in: packageURL)
            else {
                throw PackageLibraryError.unsafePackage
            }
            let relativePath = String(url.path.dropFirst(packageURL.path.count + 1))
            result.append((url, relativePath, values.isDirectory == true))
        }
        return result.sorted { $0.1 < $1.1 }
    }
}

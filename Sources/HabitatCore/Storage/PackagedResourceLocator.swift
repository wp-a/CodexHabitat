import Foundation

public enum PackagedResourceLocator {
    public static func url(
        forResource name: String,
        withExtension extensionName: String,
        subdirectory: String,
        executableURL: URL? = Bundle.main.executableURL,
        fileManager: FileManager = .default,
        packageBundleName: String? = nil
    ) -> URL? {
        guard let executableURL,
              name.range(
                of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$",
                options: .regularExpression
              ) != nil,
              extensionName.range(
                of: "^[A-Za-z0-9]{1,16}$",
                options: .regularExpression
              ) != nil,
              safeSubdirectory(subdirectory)
        else {
            return nil
        }
        let executableDirectory = executableURL.standardizedFileURL.deletingLastPathComponent()
        var roots: [URL] = []
        if ["MacOS", "Helpers"].contains(executableDirectory.lastPathComponent) {
            roots.append(
                executableDirectory.deletingLastPathComponent().appending(
                    path: "Resources",
                    directoryHint: .isDirectory
                )
            )
        }
        if let packageBundleName,
           packageBundleName.range(
            of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\\.bundle$",
            options: .regularExpression
           ) != nil {
            var directory = executableDirectory
            for _ in 0...3 {
                roots.append(
                    directory.appending(
                        path: packageBundleName,
                        directoryHint: .isDirectory
                    )
                )
                directory.deleteLastPathComponent()
            }
            if executableURL.lastPathComponent == "swiftpm-testing-helper" {
                let buildRoot = URL(
                    fileURLWithPath: fileManager.currentDirectoryPath,
                    isDirectory: true
                ).appending(path: ".build", directoryHint: .isDirectory)
                for configuration in ["debug", "release"] {
                    roots.append(
                        buildRoot
                            .appending(path: configuration, directoryHint: .isDirectory)
                            .appending(path: packageBundleName, directoryHint: .isDirectory)
                    )
                }
            }
        }
        for root in roots {
            let candidate = root
                .appending(path: subdirectory, directoryHint: .isDirectory)
                .appending(path: "\(name).\(extensionName)")
                .standardizedFileURL
            guard candidate.path.hasPrefix(root.standardizedFileURL.path + "/"),
                  fileManager.fileExists(atPath: candidate.path),
                  let values = try? candidate.resourceValues(
                    forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
                  ),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true
            else {
                continue
            }
            return candidate
        }
        return nil
    }

    private static func safeSubdirectory(_ value: String) -> Bool {
        guard !value.isEmpty,
              !NSString(string: value).isAbsolutePath,
              !value.contains("\\")
        else {
            return false
        }
        let components = value.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        return !components.isEmpty && components.allSatisfy { component in
            component != "."
                && component != ".."
                && !component.isEmpty
                && component.range(
                    of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$",
                    options: .regularExpression
                ) != nil
        }
    }
}

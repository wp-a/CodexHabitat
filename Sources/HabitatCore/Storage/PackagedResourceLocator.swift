import Foundation

public enum PackagedResourceLocator {
    public static func url(
        forResource name: String,
        withExtension extensionName: String,
        subdirectory: String,
        executableURL: URL? = Bundle.main.executableURL,
        fileManager: FileManager = .default
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
        let executableDirectory = executableURL.standardizedFileURL
            .deletingLastPathComponent()
        guard ["MacOS", "Helpers"].contains(executableDirectory.lastPathComponent)
        else {
            return nil
        }
        let contents = executableDirectory.deletingLastPathComponent()
        let resources = contents.appending(
            path: "Resources",
            directoryHint: .isDirectory
        )
        let candidate = resources
            .appending(path: subdirectory, directoryHint: .isDirectory)
            .appending(path: "\(name).\(extensionName)")
            .standardizedFileURL
        guard candidate.path.hasPrefix(resources.standardizedFileURL.path + "/"),
              fileManager.fileExists(atPath: candidate.path),
              let values = try? candidate.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
              ),
              values.isRegularFile == true,
              values.isSymbolicLink != true
        else {
            return nil
        }
        return candidate
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

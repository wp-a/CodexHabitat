import Foundation

public struct MarketplaceLicense: Equatable, Sendable {
    public let spdx: String
    public let url: URL

    public init(spdx: String, url: URL) {
        self.spdx = spdx
        self.url = url
    }
}

public struct MarketplacePet: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let kind: String
    public let author: String?
    public let previewURL: URL
    public let metadataURL: URL
    public let packageURL: URL?
    public let sourceURL: URL
    public let license: MarketplaceLicense?
    public let packageSHA256: String?
    public let contentID: String?

    public init(
        id: String,
        displayName: String,
        kind: String,
        author: String?,
        previewURL: URL,
        metadataURL: URL,
        packageURL: URL?,
        sourceURL: URL,
        license: MarketplaceLicense?,
        packageSHA256: String?,
        contentID: String?
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.author = author
        self.previewURL = previewURL
        self.metadataURL = metadataURL
        self.packageURL = packageURL
        self.sourceURL = sourceURL
        self.license = license
        self.packageSHA256 = packageSHA256
        self.contentID = contentID
    }

    public var licenseLabel: String {
        license?.spdx ?? "License not declared"
    }

    public var isInstallable: Bool {
        packageURL != nil && license != nil && packageSHA256 != nil && contentID != nil
    }
}

import Foundation

public struct PetManifest: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let spriteVersionNumber: Int?
    public let spritesheetPath: String

    public init(
        id: String,
        displayName: String,
        description: String,
        spriteVersionNumber: Int? = nil,
        spritesheetPath: String
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.spriteVersionNumber = spriteVersionNumber
        self.spritesheetPath = spritesheetPath
    }

    public var effectiveSpriteVersion: Int {
        spriteVersionNumber ?? 1
    }
}

public struct PetAtlasMetadata: Equatable, Sendable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let columns: Int
    public let rows: Int

    public init(pixelWidth: Int, pixelHeight: Int, columns: Int, rows: Int) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.columns = columns
        self.rows = rows
    }

    public var cellWidth: Int { pixelWidth / columns }
    public var cellHeight: Int { pixelHeight / rows }
}

public enum PetValidationIssue: String, Equatable, Sendable {
    case manifestMissing
    case manifestUnreadable
    case invalidIdentifier
    case unsupportedSpriteVersion
    case spritesheetPathEscapesPackage
    case spritesheetMissing
    case spritesheetUnreadable
    case invalidSpritesheetDimensions
}

public enum PetValidationStatus: Equatable, Sendable {
    case valid
    case invalid(PetValidationIssue)
    case duplicateID
}

public struct PetLibraryEntry: Equatable, Sendable {
    public let packageURL: URL
    public let manifest: PetManifest?
    public let spritesheetURL: URL?
    public let atlas: PetAtlasMetadata?
    public let status: PetValidationStatus

    public init(
        packageURL: URL,
        manifest: PetManifest?,
        spritesheetURL: URL?,
        atlas: PetAtlasMetadata?,
        status: PetValidationStatus
    ) {
        self.packageURL = packageURL
        self.manifest = manifest
        self.spritesheetURL = spritesheetURL
        self.atlas = atlas
        self.status = status
    }

    func replacingStatus(_ status: PetValidationStatus) -> PetLibraryEntry {
        PetLibraryEntry(
            packageURL: packageURL,
            manifest: manifest,
            spritesheetURL: spritesheetURL,
            atlas: atlas,
            status: status
        )
    }
}

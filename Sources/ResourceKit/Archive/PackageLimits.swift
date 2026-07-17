import Foundation

public struct PackageLimits: Equatable, Sendable {
    public var maxArchiveBytes: UInt64
    public var maxFileCount: Int
    public var maxCompressedBytes: UInt64
    public var maxUncompressedBytes: UInt64
    public var maxEntryUncompressedBytes: UInt64
    public var maxCompressionRatio: Double
    public var maxManifestBytes: UInt64
    public var maxImageWidth: Int
    public var maxImageHeight: Int
    public var maxImagePixels: Int

    public init(
        maxArchiveBytes: UInt64 = 50 * 1024 * 1024,
        maxFileCount: Int = 256,
        maxCompressedBytes: UInt64 = 50 * 1024 * 1024,
        maxUncompressedBytes: UInt64 = 200 * 1024 * 1024,
        maxEntryUncompressedBytes: UInt64 = 64 * 1024 * 1024,
        maxCompressionRatio: Double = 100,
        maxManifestBytes: UInt64 = 256 * 1024,
        maxImageWidth: Int = 8_192,
        maxImageHeight: Int = 8_192,
        maxImagePixels: Int = 32_000_000
    ) {
        self.maxArchiveBytes = maxArchiveBytes
        self.maxFileCount = maxFileCount
        self.maxCompressedBytes = maxCompressedBytes
        self.maxUncompressedBytes = maxUncompressedBytes
        self.maxEntryUncompressedBytes = maxEntryUncompressedBytes
        self.maxCompressionRatio = maxCompressionRatio
        self.maxManifestBytes = maxManifestBytes
        self.maxImageWidth = maxImageWidth
        self.maxImageHeight = maxImageHeight
        self.maxImagePixels = maxImagePixels
    }
}

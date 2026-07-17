import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import ZIPFoundation

struct TestArchiveEntry {
    let path: String
    let type: Entry.EntryType
    let data: Data
    let compression: CompressionMethod
    let permissions: UInt16?

    init(
        path: String,
        type: Entry.EntryType = .file,
        data: Data = Data(),
        compression: CompressionMethod = .none,
        permissions: UInt16? = nil
    ) {
        self.path = path
        self.type = type
        self.data = data
        self.compression = compression
        self.permissions = permissions
    }
}

func makeTestArchive(_ entries: [TestArchiveEntry]) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatArchiveTests-\(UUID().uuidString).habitat-pack")
    let archive = try Archive(url: url, accessMode: .create)
    for entry in entries {
        try archive.addEntry(
            with: entry.path,
            type: entry.type,
            uncompressedSize: Int64(entry.data.count),
            permissions: entry.permissions,
            compressionMethod: entry.compression,
            provider: { position, size in
                let start = Int(position)
                let end = min(start + size, entry.data.count)
                return entry.data.subdata(in: start..<end)
            }
        )
    }
    return url
}

func minimalManifestData(
    id: String = "studio.example.safe-pack",
    version: String = "1.0.0",
    assets: [[String: Any]] = []
) throws -> Data {
    let manifest: [String: Any] = [
        "schemaVersion": 1,
        "id": id,
        "name": "Safe Pack",
        "version": version,
        "author": "Example Studio",
        "license": ["spdx": "MIT", "file": "LICENSE"],
        "minimumRuntimeVersion": "1.0.0",
        "modes": ["light", "dark"],
        "preview": "preview.png",
        "colors": [
            "surface": "#F4F6F8",
            "text": "#1C1C1E",
            "accent": "#14B8A6",
            "attention": "#F59E0B",
            "error": "#EF4444",
        ],
        "assets": assets,
        "pets": [],
        "widgets": [],
    ]
    return try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
}

func testPNG(width: Int = 1, height: Int = 1) throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let image = context.makeImage()
    else {
        throw TestArchiveSupportError.imageCreationFailed
    }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw TestArchiveSupportError.imageCreationFailed
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw TestArchiveSupportError.imageCreationFailed
    }
    return data as Data
}

func testNoisePNG(width: Int, height: Int) throws -> Data {
    var state: UInt32 = 0xA341_316C
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for index in stride(from: 0, to: pixels.count, by: 4) {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        pixels[index] = UInt8(truncatingIfNeeded: state)
        pixels[index + 1] = UInt8(truncatingIfNeeded: state >> 8)
        pixels[index + 2] = UInt8(truncatingIfNeeded: state >> 16)
        pixels[index + 3] = 255
    }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let image = try pixels.withUnsafeMutableBytes { buffer -> CGImage in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw TestArchiveSupportError.imageCreationFailed
        }
        return image
    }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw TestArchiveSupportError.imageCreationFailed
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw TestArchiveSupportError.imageCreationFailed
    }
    return data as Data
}

enum TestArchiveSupportError: Error {
    case imageCreationFailed
}

import CoreGraphics
import Foundation
import PetRuntime
import Testing
@testable import CodexHabitatApp

@Test
func repeatedPetThumbnailRequestsReuseOneLoadedFrame() async throws {
    let image = try thumbnailTestImage()
    let counter = ThumbnailLoadCounter()
    let store = PetThumbnailStore { _ in
        counter.increment()
        return image
    }
    let pet = thumbnailTestPet()

    let first = await store.image(for: pet)
    let second = await store.image(for: pet)

    #expect(first === image)
    #expect(second === image)
    #expect(counter.value == 1)
}

@Test
func missingPetThumbnailResultsAreCached() async {
    let counter = ThumbnailLoadCounter()
    let store = PetThumbnailStore { _ in
        counter.increment()
        return nil
    }
    let pet = thumbnailTestPet()

    #expect(await store.image(for: pet) == nil)
    #expect(await store.image(for: pet) == nil)
    #expect(counter.value == 1)
}

private final class ThumbnailLoadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private func thumbnailTestPet() -> PetLibraryEntry {
    let root = URL(fileURLWithPath: "/tmp/test-thumbnail-pet", isDirectory: true)
    return PetLibraryEntry(
        packageURL: root,
        manifest: nil,
        spritesheetURL: root.appending(path: "spritesheet.png"),
        atlas: PetAtlasMetadata(pixelWidth: 8, pixelHeight: 9, columns: 8, rows: 9),
        status: .valid
    )
}

private func thumbnailTestImage() throws -> CGImage {
    let context = try #require(CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    return try #require(context.makeImage())
}

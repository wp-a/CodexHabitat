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

@Test
func differentPetThumbnailsDecodeConcurrently() async {
    let probe = ConcurrentThumbnailProbe()
    let store = PetThumbnailStore { _ in
        probe.begin()
        Thread.sleep(forTimeInterval: 0.04)
        probe.end()
        return nil
    }

    async let first = store.image(for: thumbnailTestPet(id: "first"))
    async let second = store.image(for: thumbnailTestPet(id: "second"))
    _ = await (first, second)

    #expect(probe.maximumConcurrentLoads == 2)
}

@Test
func concurrentRequestsForTheSamePetShareOneDecode() async {
    let counter = ThumbnailLoadCounter()
    let store = PetThumbnailStore { _ in
        counter.increment()
        Thread.sleep(forTimeInterval: 0.03)
        return nil
    }
    let pet = thumbnailTestPet()

    async let first = store.image(for: pet)
    async let second = store.image(for: pet)
    _ = await (first, second)

    #expect(counter.value == 1)
}

@Test
func invalidatingAMissingThumbnailAllowsRetry() async throws {
    let image = try thumbnailTestImage()
    let attempts = ThumbnailLoadCounter()
    let store = PetThumbnailStore { _ in
        attempts.increment()
        return attempts.value == 1 ? nil : image
    }
    let pet = thumbnailTestPet()

    #expect(await store.image(for: pet) == nil)
    await store.invalidate(pet)
    #expect(await store.image(for: pet) === image)
    #expect(attempts.value == 2)
}

@Test
func replacingAPetSpritesheetChangesTheViewRequestIdentity() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatPetThumbnailIdentity-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let spritesheetURL = root.appending(path: "spritesheet.png")
    try Data([0]).write(to: spritesheetURL)
    let pet = thumbnailTestPet(id: root.lastPathComponent, root: root)
    let first = PetThumbnailRequestKey(pet: pet)

    try Data([0, 1]).write(to: spritesheetURL)
    let second = PetThumbnailRequestKey(pet: pet)

    #expect(first != second)
}

@Test
func changingPetAtlasChangesTheViewRequestIdentity() {
    let root = URL(fileURLWithPath: "/tmp/pet-thumbnail-atlas", isDirectory: true)
    let first = PetThumbnailRequestKey(pet: thumbnailTestPet(id: "atlas", root: root))
    let second = PetThumbnailRequestKey(
        pet: thumbnailTestPet(
            id: "atlas",
            root: root,
            atlas: PetAtlasMetadata(pixelWidth: 16, pixelHeight: 9, columns: 16, rows: 9)
        )
    )

    #expect(first != second)
}

@Test
func petPreviewSelectionChangesImmediatelyWhileKeepingThePreviousImage() throws {
    let previousImage = try thumbnailTestImage()
    var state = PetPreviewPresentationState()
    let firstRequest = state.select(petID: "first")
    state.complete(petID: "first", request: firstRequest, image: previousImage)

    _ = state.select(petID: "second")

    #expect(state.selectedPetID == "second")
    #expect(state.status == .loading)
    #expect(state.displayedImage === previousImage)
}

@Test
func petPreviewIgnoresStaleCompletionAndKeepsOldImageOnCurrentFailure() throws {
    let previousImage = try thumbnailTestImage()
    let staleImage = try thumbnailTestImage()
    var state = PetPreviewPresentationState()
    let firstRequest = state.select(petID: "first")
    state.complete(petID: "first", request: firstRequest, image: previousImage)
    let staleRequest = state.select(petID: "second")
    let currentRequest = state.select(petID: "third")

    state.complete(petID: "second", request: staleRequest, image: staleImage)
    #expect(state.selectedPetID == "third")
    #expect(state.displayedImage === previousImage)
    #expect(state.status == .loading)

    state.complete(petID: "third", request: currentRequest, image: nil)
    #expect(state.displayedImage === previousImage)
    #expect(state.status == .failed)
}

@Test
func petRendererRecoveryShowsOnlyTheCurrentSelectionsFailure() {
    let failure = PetRendererFailure(
        petID: "second",
        message: "Unable to load pet artwork"
    )

    let matching = PetRendererRecoveryState(
        selectedPetID: "second",
        failure: failure
    )
    let stale = PetRendererRecoveryState(
        selectedPetID: "third",
        failure: failure
    )

    #expect(matching.inlineMessage == failure.message)
    #expect(stale.inlineMessage == nil)
}

@Test @MainActor
func petRendererRecoveryRetriesThePreviewAndDesktopRendererExactlyOnce() async {
    var invalidatedPetIDs: [String] = []
    var rendererRetryCount = 0
    let coordinator = PetRendererRecoveryCoordinator(
        invalidatePreview: { pet in
            invalidatedPetIDs.append(pet.packageURL.lastPathComponent)
        },
        retryRenderer: {
            rendererRetryCount += 1
        }
    )

    await coordinator.retry(pet: thumbnailTestPet(id: "second"))

    #expect(invalidatedPetIDs == ["second"])
    #expect(rendererRetryCount == 1)
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

private final class ConcurrentThumbnailProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var activeLoads = 0
    private var maximum = 0

    var maximumConcurrentLoads: Int {
        lock.withLock { maximum }
    }

    func begin() {
        lock.withLock {
            activeLoads += 1
            maximum = max(maximum, activeLoads)
        }
    }

    func end() {
        lock.withLock { activeLoads -= 1 }
    }
}

private func thumbnailTestPet(
    id: String = "test-thumbnail-pet",
    root: URL? = nil,
    atlas: PetAtlasMetadata = PetAtlasMetadata(
        pixelWidth: 8,
        pixelHeight: 9,
        columns: 8,
        rows: 9
    )
) -> PetLibraryEntry {
    let root = root ?? URL(fileURLWithPath: "/tmp/\(id)", isDirectory: true)
    return PetLibraryEntry(
        packageURL: root,
        manifest: nil,
        spritesheetURL: root.appending(path: "spritesheet.png"),
        atlas: atlas,
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

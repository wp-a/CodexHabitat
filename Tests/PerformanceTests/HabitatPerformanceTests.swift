import Foundation
import HabitatCore
import PetRuntime
import ResourceKit
import Testing

@Test
func animationFrameCalculationHasConstantClockWork() {
    let firstClock = CountingAnimationClock()
    let secondClock = CountingAnimationClock()
    var first = PetAnimator(clock: firstClock, initialActivity: .working)
    var second = PetAnimator(clock: secondClock, initialActivity: .working)
    var firstChecksum = 0
    var secondChecksum = 0

    for index in 0..<10_000 {
        let timestamp = UInt64(index * 17)
        firstClock.set(timestamp)
        secondClock.set(timestamp)
        let firstFrame = first.currentFrame()
        let secondFrame = second.currentFrame()
        firstChecksum = firstChecksum &* 31 &+ firstFrame.column
        secondChecksum = secondChecksum &* 31 &+ secondFrame.column
    }

    #expect(firstChecksum == secondChecksum)
    #expect(firstClock.readCount == 10_001)
    #expect(secondClock.readCount == 10_001)
}

@Test
func installedPackageScanHandlesOneHundredDeterministicFixtures() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "HabitatPackageScanBudget-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    for index in 0..<100 {
        try writeInstalledManifest(
            root: root,
            id: String(format: "studio.example.pack-%03d", index)
        )
    }

    let library = InstalledPackageLibrary(root: root, runtimeVersion: "1.0.0")
    let first = library.currentPackages()
    let second = library.currentPackages()

    #expect(first.count == 100)
    #expect(first.map(\.id) == second.map(\.id))
    #expect(first.first?.id == "studio.example.pack-000")
    #expect(first.last?.id == "studio.example.pack-099")
}

@Test
func snapshotPublicationCoalescesBurstsToTheNewestValue() async {
    let state = HabitatState(initialSnapshot: HabitatSnapshot(activity: .resting))
    let stream = await state.snapshots()
    for index in 0..<100 {
        await state.update(
            activity: .working,
            threadIDHash: String(index),
            eventTimestamp: Date(timeIntervalSince1970: Double(index))
        )
    }
    var iterator = stream.makeAsyncIterator()
    let newest = await iterator.next()

    #expect(newest?.threadIDHash == "99")
    #expect(newest?.eventTimestamp == Date(timeIntervalSince1970: 99))
}

@Test
func idleAndActiveRefreshCadenceStayWithinFixedBudgets() {
    #expect(PetRefreshPolicy.interval(activity: .offline, reduceMotion: false) == nil)
    #expect(PetRefreshPolicy.interval(activity: .resting, reduceMotion: false) == nil)
    #expect(PetRefreshPolicy.interval(activity: .working, reduceMotion: false) == 0.125)
    #expect(PetRefreshPolicy.interval(activity: .attention, reduceMotion: false) == 0.125)
    #expect(PetRefreshPolicy.interval(activity: .succeeded, reduceMotion: false) == 0.125)
    #expect(PetRefreshPolicy.interval(activity: .failed, reduceMotion: false) == 0.125)
    #expect(PetRefreshPolicy.interval(activity: .working, reduceMotion: true) == nil)
}

private final class CountingAnimationClock: AnimationClock, @unchecked Sendable {
    private let lock = NSLock()
    private var timestamp: UInt64 = 0
    private(set) var readCount = 0

    func nowMilliseconds() -> UInt64 {
        lock.withLock {
            readCount += 1
            return timestamp
        }
    }

    func set(_ timestamp: UInt64) {
        lock.withLock { self.timestamp = timestamp }
    }
}

private func writeInstalledManifest(root: URL, id: String) throws {
    let directory = root.appending(path: "\(id)/1.0.0", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let object: [String: Any] = [
        "schemaVersion": 1,
        "id": id,
        "name": "Performance Fixture",
        "version": "1.0.0",
        "author": "Codex Habitat",
        "license": ["spdx": "MIT", "file": "LICENSE"],
        "minimumRuntimeVersion": "1.0.0",
        "modes": ["light"],
        "preview": "preview.png",
        "colors": [
            "surface": "#FFFFFF",
            "text": "#111111",
            "accent": "#008080",
            "attention": "#D97706",
            "error": "#D64545",
        ],
        "assets": [],
        "pets": [],
        "widgets": [],
    ]
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    try data.write(to: directory.appending(path: "habitat.json"))
}

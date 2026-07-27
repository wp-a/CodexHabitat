import AppKit
import CoreGraphics
import Foundation
import HabitatCore
import PetRuntime
import Testing
import WidgetRuntime
@testable import CodexHabitatApp

@Test @MainActor
func petAnimationDriverAdvancesWithoutMutatingTheOverlayModel() {
    let clock = OverlayTestClock()
    let model = HabitatOverlayModel(clock: clock, initialSnapshot: HabitatSnapshot(
        activity: .resting,
        connectionHealth: .online
    ))
    let driver = PetAnimationDriver(
        clock: clock,
        initialActivity: model.snapshot.activity,
        availableRows: model.availableRows,
        reduceMotion: model.reduceMotion
    )
    let originalSize = model.overlaySize

    model.apply(HabitatSnapshot(activity: .working, connectionHealth: .online))
    driver.update(activity: model.snapshot.activity)
    #expect(driver.currentFrame().animation == .running)
    #expect(driver.currentFrame().row == 7)
    #expect(driver.currentFrame().column == 0)
    #expect(driver.refreshInterval == 0.125)

    clock.set(121)
    #expect(driver.currentFrame().column == 1)
    #expect(model.overlaySize == originalSize)
}

@Test @MainActor
func inactiveAndReducedMotionPetDriversInstallNoRefreshTimer() {
    let clock = OverlayTestClock()
    let inactive = PetAnimationDriver(
        clock: clock,
        initialActivity: .offline,
        availableRows: Set(0..<9),
        reduceMotion: false
    )
    let reduced = PetAnimationDriver(
        clock: clock,
        initialActivity: .working,
        availableRows: Set(0..<9),
        reduceMotion: true
    )

    #expect(inactive.refreshInterval == nil)
    #expect(reduced.refreshInterval == nil)
    #expect(inactive.currentFrame() == PetFrame(animation: .idle, row: 0, column: 0))
    #expect(reduced.currentFrame() == PetFrame(animation: .idle, row: 0, column: 0))
}

@Test @MainActor
func petSpriteAnimationResumesAfterTheViewReattachesToItsWindow() throws {
    let clock = OverlayTestClock()
    let atlas = PetAtlasMetadata(pixelWidth: 32, pixelHeight: 36, columns: 8, rows: 9)
    let context = try #require(CGContext(
        data: nil,
        width: atlas.pixelWidth,
        height: atlas.pixelHeight,
        bitsPerComponent: 8,
        bytesPerRow: atlas.pixelWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 4, width: 4, height: 4))
    context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
    context.fill(CGRect(x: 4, y: 4, width: 4, height: 4))
    let renderer = SpriteSheetRenderer(image: context.makeImage(), atlas: atlas)
    let sourceFirstFrame = try #require(renderer.frame(row: 7, column: 0))
    let sourceSecondFrame = try #require(renderer.frame(row: 7, column: 1))
    #expect(firstPixel(in: sourceFirstFrame) != firstPixel(in: sourceSecondFrame))
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 136, height: 144),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )
    let contentView = try #require(window.contentView)
    let spriteView = PetSpriteNSView(frame: contentView.bounds)
    contentView.addSubview(spriteView)
    spriteView.configure(
        activity: .working,
        renderer: renderer,
        interpolation: .nearest,
        clock: clock,
        availableRows: Set(0..<9),
        reduceMotion: false
    )
    let firstFramePixel = try #require(renderedFirstPixel(in: spriteView))

    spriteView.removeFromSuperview()
    clock.set(121)
    contentView.addSubview(spriteView)
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))

    #expect(try #require(renderedFirstPixel(in: spriteView)) != firstFramePixel)
}

@Test @MainActor
func focusedPetSpriteRebuildsItsDriverForEveryPlaybackIdentityInput() throws {
    let atlas = PetAtlasMetadata(pixelWidth: 32, pixelHeight: 36, columns: 8, rows: 9)
    let firstRenderer = try petSpriteRenderer(atlas: atlas, red: 1, green: 0)
    let secondRenderer = try petSpriteRenderer(atlas: atlas, red: 0, green: 1)
    let firstClock = OverlayTestClock()
    let secondClock = OverlayTestClock()
    let view = PetSpriteNSView()

    view.configure(
        activity: .working,
        renderer: firstRenderer,
        interpolation: .nearest,
        clock: firstClock,
        availableRows: Set(0..<9),
        reduceMotion: false
    )
    #expect(view.animationDriverBuildCount == 1)

    view.configure(
        activity: .attention,
        renderer: firstRenderer,
        interpolation: .linear,
        clock: firstClock,
        availableRows: Set(0..<9),
        reduceMotion: false
    )
    #expect(view.animationDriverBuildCount == 1)

    view.configure(
        activity: .attention,
        renderer: secondRenderer,
        interpolation: .linear,
        clock: firstClock,
        availableRows: Set(0..<9),
        reduceMotion: false
    )
    #expect(view.animationDriverBuildCount == 2)

    view.configure(
        activity: .attention,
        renderer: secondRenderer,
        interpolation: .linear,
        clock: firstClock,
        availableRows: [0],
        reduceMotion: false
    )
    #expect(view.animationDriverBuildCount == 3)

    view.configure(
        activity: .attention,
        renderer: secondRenderer,
        interpolation: .linear,
        clock: secondClock,
        availableRows: [0],
        reduceMotion: false
    )
    #expect(view.animationDriverBuildCount == 4)

    view.configure(
        activity: .attention,
        renderer: secondRenderer,
        interpolation: .linear,
        clock: secondClock,
        availableRows: [0],
        reduceMotion: true
    )
    #expect(view.animationDriverBuildCount == 5)
}

@Test @MainActor
func countdownControlsRunPauseAndReset() {
    let clock = OverlayTimerClock()
    let model = WidgetRailModel(
        countdownConfiguration: CountdownConfiguration(durationSeconds: 10),
        timerClock: clock
    )

    model.toggleCountdown()
    clock.advance(seconds: 4)
    model.refreshTimersForTesting()
    #expect(model.countdownSnapshot.remainingSeconds == 6)
    #expect(model.countdownSnapshot.isRunning)

    model.toggleCountdown()
    model.resetCountdown()
    #expect(model.countdownSnapshot.remainingSeconds == 10)
    #expect(!model.countdownSnapshot.isRunning)
}

private final class OverlayTimerClock: TimerClock, @unchecked Sendable {
    private var date = Date(timeIntervalSince1970: 1_700_000_000)

    func now() -> Date { date }
    func advance(seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }
}

private final class OverlayTestClock: AnimationClock, @unchecked Sendable {
    private var milliseconds: UInt64 = 0

    func nowMilliseconds() -> UInt64 { milliseconds }
    func set(_ value: UInt64) { milliseconds = value }
}

private func petSpriteRenderer(
    atlas: PetAtlasMetadata,
    red: CGFloat,
    green: CGFloat
) throws -> SpriteSheetRenderer {
    let context = try #require(CGContext(
        data: nil,
        width: atlas.pixelWidth,
        height: atlas.pixelHeight,
        bitsPerComponent: 8,
        bytesPerRow: atlas.pixelWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: red, green: green, blue: 0, alpha: 1))
    context.fill(CGRect(origin: .zero, size: CGSize(width: atlas.pixelWidth, height: atlas.pixelHeight)))
    return SpriteSheetRenderer(image: context.makeImage(), atlas: atlas)
}

@MainActor
private func renderedFirstPixel(in view: PetSpriteNSView) -> [UInt8]? {
    guard let contents = view.layer?.contents else { return nil }
    let object = contents as CFTypeRef
    guard CFGetTypeID(object) == CGImage.typeID else { return nil }
    let image: CGImage = unsafeDowncast(contents as AnyObject, to: CGImage.self)
    return firstPixel(in: image)
}

private func firstPixel(in image: CGImage) -> [UInt8]? {
    guard let data = image.dataProvider?.data,
          let bytes = CFDataGetBytePtr(data)
    else {
        return nil
    }
    return Array(UnsafeBufferPointer(start: bytes, count: 4))
}

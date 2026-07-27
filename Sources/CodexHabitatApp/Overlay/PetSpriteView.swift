import AppKit
import HabitatCore
import PetRuntime
import QuartzCore
import SwiftUI

@MainActor
final class PetAnimationDriver {
    private var animator: PetAnimator
    private(set) var activity: AgentActivity
    let reduceMotion: Bool

    init(
        clock: any AnimationClock,
        initialActivity: AgentActivity,
        availableRows: Set<Int>,
        reduceMotion: Bool
    ) {
        activity = initialActivity
        animator = PetAnimator(
            clock: clock,
            initialActivity: initialActivity,
            availableRows: availableRows,
            reduceMotion: reduceMotion
        )
        self.reduceMotion = reduceMotion
    }

    var refreshInterval: TimeInterval? {
        PetRefreshPolicy.interval(activity: activity, reduceMotion: reduceMotion)
    }

    func update(activity: AgentActivity) {
        self.activity = activity
        _ = animator.update(activity: activity)
    }

    func currentFrame() -> PetFrame {
        animator.currentFrame()
    }
}

struct PetSpriteView: NSViewRepresentable {
    let activity: AgentActivity
    let renderer: SpriteSheetRenderer
    let renderMode: PetRenderMode
    let pixelArtHint: Bool
    let clock: any AnimationClock
    let availableRows: Set<Int>
    let reduceMotion: Bool

    func makeNSView(context _: Context) -> PetSpriteNSView {
        let view = PetSpriteNSView()
        view.configure(
            activity: activity,
            renderer: renderer,
            interpolation: interpolation,
            clock: clock,
            availableRows: availableRows,
            reduceMotion: reduceMotion
        )
        return view
    }

    func updateNSView(_ view: PetSpriteNSView, context _: Context) {
        view.configure(
            activity: activity,
            renderer: renderer,
            interpolation: interpolation,
            clock: clock,
            availableRows: availableRows,
            reduceMotion: reduceMotion
        )
    }

    static func dismantleNSView(_ view: PetSpriteNSView, coordinator _: ()) {
        view.stopAnimating()
    }

    private var interpolation: CALayerContentsFilter {
        renderMode.resolved(pixelArtHint: pixelArtHint) == .pixelated ? .nearest : .linear
    }
}

private struct PetSpritePlaybackIdentity: Equatable {
    private enum ClockIdentity: Equatable {
        case reference(ObjectIdentifier)
        case valueType(ObjectIdentifier)

        init(_ clock: any AnimationClock) {
            if Mirror(reflecting: clock).displayStyle == .class {
                self = .reference(ObjectIdentifier(clock as AnyObject))
            } else {
                self = .valueType(ObjectIdentifier(type(of: clock)))
            }
        }
    }

    let rendererFrame: ObjectIdentifier?
    let atlas: PetAtlasMetadata
    let availableRows: Set<Int>
    private let clock: ClockIdentity
    let reduceMotion: Bool

    init(
        renderer: SpriteSheetRenderer,
        availableRows: Set<Int>,
        clock: any AnimationClock,
        reduceMotion: Bool
    ) {
        rendererFrame = (0..<renderer.atlas.rows).lazy.compactMap {
            renderer.frame(row: $0, column: 0)
        }.first.map(ObjectIdentifier.init)
        atlas = renderer.atlas
        self.availableRows = availableRows
        self.clock = ClockIdentity(clock)
        self.reduceMotion = reduceMotion
    }
}

@MainActor
final class PetSpriteNSView: NSView {
    private var driver: PetAnimationDriver?
    private var playbackIdentity: PetSpritePlaybackIdentity?
    private var renderer: SpriteSheetRenderer?
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval?
    private var interpolation = CALayerContentsFilter.linear
    private var lastRenderedImage: CGImage?
    private var occlusionObserver: (any NSObjectProtocol)?
    private(set) var animationDriverBuildCount = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.contentsGravity = .resizeAspect
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        layer?.contentsScale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        guard let window else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateTimerIfNeeded()
                self?.renderCurrentFrame()
            }
        }
        updateTimerIfNeeded()
        renderCurrentFrame()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
        }
        if newWindow == nil {
            stopAnimating()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    func configure(
        activity: AgentActivity,
        renderer: SpriteSheetRenderer,
        interpolation: CALayerContentsFilter,
        clock: any AnimationClock,
        availableRows: Set<Int>,
        reduceMotion: Bool
    ) {
        self.renderer = renderer
        self.interpolation = interpolation
        layer?.magnificationFilter = interpolation
        layer?.minificationFilter = interpolation

        let nextIdentity = PetSpritePlaybackIdentity(
            renderer: renderer,
            availableRows: availableRows,
            clock: clock,
            reduceMotion: reduceMotion
        )
        if let driver, playbackIdentity == nextIdentity {
            driver.update(activity: activity)
        } else {
            driver = PetAnimationDriver(
                clock: clock,
                initialActivity: activity,
                availableRows: availableRows,
                reduceMotion: reduceMotion
            )
            playbackIdentity = nextIdentity
            animationDriverBuildCount += 1
        }
        updateTimerIfNeeded()
        renderCurrentFrame()
    }

    func stopAnimating() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshInterval = nil
    }

    private func updateTimerIfNeeded() {
        let desiredInterval = effectiveRefreshInterval
        guard desiredInterval != refreshInterval else { return }
        stopAnimating()
        guard let desiredInterval else { return }

        refreshInterval = desiredInterval
        let timer = Timer(timeInterval: desiredInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.renderCurrentFrame()
            }
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private var effectiveRefreshInterval: TimeInterval? {
        guard let window else { return nil }
        guard window.occlusionState.contains(.visible) else { return nil }
        return driver?.refreshInterval
    }

    private func renderCurrentFrame() {
        let image = driver.flatMap { renderer?.frame($0.currentFrame()) }
            ?? cachedFallbackImage
        guard image !== lastRenderedImage else { return }
        lastRenderedImage = image
        layer?.contents = image
    }

    private lazy var cachedFallbackImage: CGImage? = {
        guard let image = NSImage(
            systemSymbolName: "pawprint.fill",
            accessibilityDescription: nil
        ) else {
            return nil
        }
        var rect = NSRect(x: 0, y: 0, width: 64, height: 64)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }()
}

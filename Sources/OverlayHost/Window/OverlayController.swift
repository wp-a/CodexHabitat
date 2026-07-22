import AppKit
import SwiftUI

@MainActor
public final class OverlayController: NSObject {
    public let panel: HabitatPanel
    public private(set) var isInteractive = false
    public private(set) var isMovementLocked = false
    public var onPlacementChange: ((SavedOverlayPlacement) -> Void)?
    public var onPrimaryClick: (() -> Void)? {
        didSet { dragRegion.onClick = onPrimaryClick }
    }
    public var onPrimaryPressChange: ((Bool) -> Void)? {
        didSet { dragRegion.onPressChange = onPrimaryPressChange }
    }

    public var isMovementEnabled: Bool {
        isInteractive && !isMovementLocked
    }

    public var dragRegionFrame: CGRect { dragRegion.frame }

    private var panelSize: CGSize
    private let snapper: EdgeSnapper
    private let hostingView: NSHostingView<AnyView>
    private let dragRegion = OverlayDragRegionView()
    private var savedPlacement: SavedOverlayPlacement?

    public init(panelSize: CGSize = CGSize(width: 160, height: 180), snapThreshold: CGFloat = 12) {
        self.panelSize = panelSize
        snapper = EdgeSnapper(threshold: snapThreshold)
        panel = HabitatPanel(contentRect: NSRect(origin: .zero, size: panelSize))
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        super.init()
        configureContentView()
        configureDragRegion()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        setInteractive(false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func setContent<Content: View>(_ content: Content) {
        hostingView.rootView = AnyView(content)
    }

    public func show(savedPlacement: SavedOverlayPlacement? = nil) {
        let displays = currentDisplays()
        let fallbackID = screenID(NSScreen.main)
        if let savedPlacement,
           let resolved = DisplayGeometry.resolve(
               saved: savedPlacement,
               panelSize: panelSize,
               displays: displays,
               fallbackDisplayID: fallbackID
           ) {
            panel.setFrameOrigin(resolved.origin)
            self.savedPlacement = SavedOverlayPlacement(
                displayID: resolved.display.id,
                relativePosition: resolved.display.relativePosition(
                    for: resolved.origin,
                    panelSize: panelSize
                )
            )
        } else if let display = display(for: NSScreen.main) ?? displays.first {
            let origin = CGPoint(
                x: display.visibleFrame.maxX - panelSize.width - 24,
                y: display.visibleFrame.minY + 24
            )
            let clamped = display.clampedOrigin(origin, panelSize: panelSize)
            panel.setFrameOrigin(clamped)
            self.savedPlacement = SavedOverlayPlacement(
                displayID: display.id,
                relativePosition: display.relativePosition(for: clamped, panelSize: panelSize)
            )
        }
        panel.orderFrontRegardless()
    }

    public func setInteractive(_ interactive: Bool) {
        isInteractive = interactive
        panel.ignoresMouseEvents = !interactive
        updateDragRegion()
    }

    public func setMovementLocked(_ locked: Bool) {
        guard locked != isMovementLocked else { return }
        dragRegion.cancelPointerInteraction()
        isMovementLocked = locked
        updateDragRegion()
    }

    public func setDragFrame(_ frame: CGRect) {
        let panelBounds = CGRect(origin: .zero, size: panelSize)
        let clippedFrame = frame.standardized.intersection(panelBounds)
        dragRegion.frame = clippedFrame.isNull ? .zero : clippedFrame
    }

    public func resize(
        to requestedSize: CGSize,
        preservingRightEdge: Bool = true,
        rightEdgeAnchor: CGFloat? = nil
    ) {
        dragRegion.cancelPointerInteraction()
        let nextSize = Self.boundedSize(requestedSize)
        guard nextSize != panelSize else { return }

        let oldFrame = panel.frame
        let activeDisplay = display(for: panel.screen)
            ?? display(containingPanelAt: oldFrame.origin)
        var origin = oldFrame.origin
        if preservingRightEdge {
            origin.x = (rightEdgeAnchor ?? oldFrame.maxX) - nextSize.width
        }
        if let activeDisplay {
            origin = activeDisplay.clampedOrigin(origin, panelSize: nextSize)
        }
        panel.setFrame(CGRect(origin: origin, size: nextSize), display: true)
        let appliedSize = panel.frame.size
        if preservingRightEdge {
            var correctedOrigin = panel.frame.origin
            correctedOrigin.x = (rightEdgeAnchor ?? oldFrame.maxX) - appliedSize.width
            if let activeDisplay {
                correctedOrigin = activeDisplay.clampedOrigin(
                    correctedOrigin,
                    panelSize: appliedSize
                )
            }
            panel.setFrameOrigin(correctedOrigin)
            origin = correctedOrigin
        } else {
            origin = panel.frame.origin
        }
        panelSize = appliedSize
        let clippedDragFrame = dragRegion.frame.intersection(
            CGRect(origin: .zero, size: appliedSize)
        )
        dragRegion.frame = clippedDragFrame.isNull ? .zero : clippedDragFrame

        guard let activeDisplay else { return }
        savedPlacement = SavedOverlayPlacement(
            displayID: activeDisplay.id,
            relativePosition: activeDisplay.relativePosition(
                for: origin,
                panelSize: appliedSize
            )
        )
    }

    public func hide() {
        dragRegion.cancelPointerInteraction()
        panel.orderOut(nil)
    }

    public func currentPlacement() -> SavedOverlayPlacement? {
        savedPlacement
    }

    private func configureContentView() {
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        panel.contentView = container
    }

    private func configureDragRegion() {
        guard let contentView = panel.contentView else { return }
        dragRegion.frame = contentView.bounds
        dragRegion.onMove = { [weak self] origin in
            self?.move(to: origin)
        }
        dragRegion.onFinish = { [weak self] origin in
            self?.finishMove(at: origin)
        }
        contentView.addSubview(dragRegion)
    }

    private func move(to proposedOrigin: CGPoint) {
        guard let display = display(containingPanelAt: proposedOrigin) else { return }
        panel.setFrameOrigin(display.clampedOrigin(proposedOrigin, panelSize: panelSize))
    }

    private func finishMove(at proposedOrigin: CGPoint) {
        guard let display = display(containingPanelAt: proposedOrigin) else { return }
        let snapped = snapper.snappedOrigin(
            proposedOrigin,
            panelSize: panelSize,
            visibleFrame: display.visibleFrame
        )
        panel.setFrameOrigin(snapped)
        savedPlacement = SavedOverlayPlacement(
            displayID: display.id,
            relativePosition: display.relativePosition(for: snapped, panelSize: panelSize)
        )
        if let savedPlacement {
            onPlacementChange?(savedPlacement)
        }
    }

    @objc private func screenParametersChanged() {
        guard let savedPlacement,
              let resolved = DisplayGeometry.resolve(
                  saved: savedPlacement,
                  panelSize: panelSize,
                  displays: currentDisplays(),
                  fallbackDisplayID: screenID(NSScreen.main)
              )
        else {
            return
        }
        panel.setFrameOrigin(resolved.origin)
        self.savedPlacement = SavedOverlayPlacement(
            displayID: resolved.display.id,
            relativePosition: resolved.display.relativePosition(
                for: resolved.origin,
                panelSize: panelSize
            )
        )
        if let savedPlacement = self.savedPlacement {
            onPlacementChange?(savedPlacement)
        }
    }

    private func updateDragRegion() {
        dragRegion.isInteractionEnabled = isInteractive
        dragRegion.isDragEnabled = isMovementEnabled
        dragRegion.isHidden = !isInteractive
    }

    private func display(containingPanelAt origin: CGPoint) -> DisplayGeometry? {
        let center = CGPoint(x: origin.x + panelSize.width / 2, y: origin.y + panelSize.height / 2)
        return currentDisplays().first(where: { $0.frame.contains(center) })
            ?? display(for: panel.screen)
            ?? display(for: NSScreen.main)
    }

    private func currentDisplays() -> [DisplayGeometry] {
        NSScreen.screens.compactMap(display(for:))
    }

    private func display(for screen: NSScreen?) -> DisplayGeometry? {
        guard let screen, let id = screenID(screen) else { return nil }
        return DisplayGeometry(
            id: id,
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            backingScaleFactor: screen.backingScaleFactor
        )
    }

    private func screenID(_ screen: NSScreen?) -> String? {
        guard let number = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            as? NSNumber
        else {
            return nil
        }
        return number.stringValue
    }

    private static func boundedSize(_ requested: CGSize) -> CGSize {
        let width = requested.width.isFinite ? requested.width : 64
        let height = requested.height.isFinite ? requested.height : 64
        return CGSize(
            width: min(max(width, 64), 2_048),
            height: min(max(height, 64), 2_048)
        )
    }
}

@MainActor
final class OverlayDragRegionView: NSView {
    var isInteractionEnabled = false {
        didSet {
            if !isInteractionEnabled {
                cancelPointerInteraction()
            }
        }
    }
    var isDragEnabled = false
    var onMove: ((CGPoint) -> Void)?
    var onFinish: ((CGPoint) -> Void)?
    var onClick: (() -> Void)?
    var onPressChange: ((Bool) -> Void)?

    private var interaction = PetPointerInteraction(dragThreshold: 6)

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return super.hitTest(point) }
        return Self.ownsPrimaryPointerEvent(event) ? super.hitTest(point) : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard isInteractionEnabled,
              Self.ownsPrimaryPointerEvent(event),
              let window
        else {
            return
        }
        handlePointerDown(
            at: screenLocation(for: event, in: window),
            windowOrigin: window.frame.origin
        )
    }

    override func mouseDragged(with event: NSEvent) {
        guard isInteractionEnabled, let window else { return }
        handlePointerMoved(to: screenLocation(for: event, in: window))
    }

    override func mouseUp(with event: NSEvent) {
        guard isInteractionEnabled, let window else { return }
        handlePointerUp(at: screenLocation(for: event, in: window))
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            cancelPointerInteraction()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    func cancelPointerInteraction() {
        consume(interaction.cancel())
    }

    func handlePointerDown(at location: CGPoint, windowOrigin: CGPoint) {
        guard isInteractionEnabled else { return }
        consume(interaction.pointerDown(
            at: location,
            windowOrigin: windowOrigin,
            canDrag: isDragEnabled
        ))
    }

    func handlePointerMoved(to location: CGPoint) {
        guard isInteractionEnabled else { return }
        consume(interaction.pointerMoved(to: location))
    }

    func handlePointerUp(at location: CGPoint) {
        guard isInteractionEnabled else { return }
        consume(interaction.pointerUp(at: location))
    }

    private func screenLocation(for event: NSEvent, in window: NSWindow) -> CGPoint {
        window.convertPoint(toScreen: event.locationInWindow)
    }

    private static func ownsPrimaryPointerEvent(_ event: NSEvent) -> Bool {
        PetPointerInteraction.ownsPrimaryButton(
            buttonNumber: event.buttonNumber,
            controlPressed: event.modifierFlags.contains(.control)
        )
    }

    private func consume(_ update: PetPointerInteraction.Update) {
        if let pressed = update.pressChanged {
            onPressChange?(pressed)
        }
        switch update.command {
        case .toggle:
            onClick?()
        case let .move(origin):
            onMove?(origin)
        case let .finishMove(origin):
            onFinish?(origin)
        case nil:
            break
        }
    }
}

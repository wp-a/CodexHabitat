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

    public var isMovementEnabled: Bool {
        isInteractive && !isMovementLocked
    }

    public var dragRegionFrame: CGRect { dragRegion.frame }

    private let panelSize: CGSize
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
        isMovementLocked = locked
        updateDragRegion()
    }

    public func setDragFrame(_ frame: CGRect) {
        let panelBounds = CGRect(origin: .zero, size: panelSize)
        dragRegion.frame = frame.standardized.intersection(panelBounds)
    }

    public func hide() {
        panel.orderOut(nil)
    }

    public func currentPlacement() -> SavedOverlayPlacement? {
        savedPlacement
    }

    private func configureContentView() {
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
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
        dragRegion.isDragEnabled = isMovementEnabled
        dragRegion.isHidden = !isMovementEnabled
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
}

@MainActor
private final class OverlayDragRegionView: NSView {
    var isDragEnabled = false
    var onMove: ((CGPoint) -> Void)?
    var onFinish: ((CGPoint) -> Void)?
    var onClick: (() -> Void)?

    private var initialMouseLocation = CGPoint.zero
    private var initialWindowOrigin = CGPoint.zero
    private var didBeginDragging = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        switch NSApp.currentEvent?.type {
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
            nil
        default:
            super.hitTest(point)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isDragEnabled, let window else { return }
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window.frame.origin
        didBeginDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragEnabled else { return }
        let location = NSEvent.mouseLocation
        let deltaX = location.x - initialMouseLocation.x
        let deltaY = location.y - initialMouseLocation.y
        guard didBeginDragging || hypot(deltaX, deltaY) >= 3 else { return }
        didBeginDragging = true
        onMove?(
            CGPoint(
                x: initialWindowOrigin.x + deltaX,
                y: initialWindowOrigin.y + deltaY
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragEnabled, let window else { return }
        if didBeginDragging {
            onFinish?(window.frame.origin)
        } else {
            onClick?()
        }
    }
}

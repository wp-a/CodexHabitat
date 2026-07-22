import CoreGraphics

public struct PetPointerInteraction: Sendable {
    public enum Command: Equatable, Sendable {
        case toggle
        case move(to: CGPoint)
        case finishMove(at: CGPoint)
    }

    public struct Update: Equatable, Sendable {
        public static let none = Update()

        public let pressChanged: Bool?
        public let command: Command?

        public init(pressChanged: Bool? = nil, command: Command? = nil) {
            self.pressChanged = pressChanged
            self.command = command
        }
    }

    private struct ActivePointer: Sendable {
        let initialLocation: CGPoint
        let grabOffset: CGPoint
        let canDrag: Bool
        var isDragging: Bool
    }

    private let dragThreshold: CGFloat
    private var activePointer: ActivePointer?

    public init(dragThreshold: CGFloat = 6) {
        self.dragThreshold = max(0, dragThreshold.isFinite ? dragThreshold : 6)
    }

    public static func ownsPrimaryButton(
        buttonNumber: Int,
        controlPressed: Bool
    ) -> Bool {
        buttonNumber == 0 && !controlPressed
    }

    public mutating func pointerDown(
        at location: CGPoint,
        windowOrigin: CGPoint,
        canDrag: Bool = true
    ) -> Update {
        activePointer = ActivePointer(
            initialLocation: location,
            grabOffset: CGPoint(
                x: location.x - windowOrigin.x,
                y: location.y - windowOrigin.y
            ),
            canDrag: canDrag,
            isDragging: false
        )
        return Update(pressChanged: true)
    }

    public mutating func pointerMoved(to location: CGPoint) -> Update {
        guard var pointer = activePointer else { return .none }
        let distance = hypot(
            location.x - pointer.initialLocation.x,
            location.y - pointer.initialLocation.y
        )
        guard pointer.isDragging || distance >= dragThreshold else { return .none }
        pointer.isDragging = true
        activePointer = pointer
        guard pointer.canDrag else { return .none }
        return Update(command: .move(to: origin(for: location, pointer: pointer)))
    }

    public mutating func pointerUp(at location: CGPoint) -> Update {
        guard var pointer = activePointer else { return .none }
        activePointer = nil
        let distance = hypot(
            location.x - pointer.initialLocation.x,
            location.y - pointer.initialLocation.y
        )
        pointer.isDragging = pointer.isDragging || (pointer.canDrag && distance >= dragThreshold)
        let command: Command?
        if pointer.isDragging {
            command = pointer.canDrag
                ? .finishMove(at: origin(for: location, pointer: pointer))
                : nil
        } else {
            command = .toggle
        }
        return Update(pressChanged: false, command: command)
    }

    public mutating func cancel() -> Update {
        guard activePointer != nil else { return .none }
        activePointer = nil
        return Update(pressChanged: false)
    }

    private func origin(for location: CGPoint, pointer: ActivePointer) -> CGPoint {
        CGPoint(
            x: location.x - pointer.grabOffset.x,
            y: location.y - pointer.grabOffset.y
        )
    }
}

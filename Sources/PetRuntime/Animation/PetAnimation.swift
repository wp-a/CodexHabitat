public enum PetAnimation: String, CaseIterable, Codable, Equatable, Sendable {
    case idle
    case runningRight = "running-right"
    case runningLeft = "running-left"
    case waving
    case jumping
    case failed
    case waiting
    case running
    case review

    public var rowIndex: Int {
        switch self {
        case .idle: 0
        case .runningRight: 1
        case .runningLeft: 2
        case .waving: 3
        case .jumping: 4
        case .failed: 5
        case .waiting: 6
        case .running: 7
        case .review: 8
        }
    }

    public var frameDurationsMilliseconds: [UInt64] {
        switch self {
        case .idle:
            [280, 110, 110, 140, 140, 320]
        case .runningRight, .runningLeft:
            [120, 120, 120, 120, 120, 120, 120, 220]
        case .waving:
            [140, 140, 140, 280]
        case .jumping:
            [140, 140, 140, 140, 280]
        case .failed:
            [140, 140, 140, 140, 140, 140, 140, 240]
        case .waiting:
            [150, 150, 150, 150, 150, 260]
        case .running:
            [120, 120, 120, 120, 120, 220]
        case .review:
            [150, 150, 150, 150, 150, 280]
        }
    }

    public var frameCount: Int {
        frameDurationsMilliseconds.count
    }

    public var totalDurationMilliseconds: UInt64 {
        frameDurationsMilliseconds.reduce(0, +)
    }

    public func frameColumn(elapsedMilliseconds: UInt64) -> Int {
        let durations = frameDurationsMilliseconds
        let elapsed = elapsedMilliseconds % totalDurationMilliseconds
        var boundary: UInt64 = 0
        for (index, duration) in durations.enumerated() {
            boundary += duration
            if elapsed < boundary {
                return index
            }
        }
        return 0
    }
}

public struct PetFrame: Equatable, Sendable {
    public let animation: PetAnimation
    public let row: Int
    public let column: Int

    public init(animation: PetAnimation, row: Int, column: Int) {
        self.animation = animation
        self.row = row
        self.column = column
    }
}

import Foundation

public struct ReconnectPolicy: Equatable, Sendable {
    public let baseDelay: Double
    public let maximumDelay: Double
    public let jitterFraction: Double
    private var attempt = 0

    public init(
        baseDelay: Double = 0.5,
        maximumDelay: Double = 30,
        jitterFraction: Double = 0.2
    ) {
        precondition(baseDelay > 0)
        precondition(maximumDelay >= baseDelay)
        precondition((0...1).contains(jitterFraction))
        self.baseDelay = baseDelay
        self.maximumDelay = maximumDelay
        self.jitterFraction = jitterFraction
    }

    public mutating func nextDelay(randomUnit: Double = Double.random(in: 0...1)) -> Double {
        let unit = min(max(randomUnit, 0), 1)
        let exponential = min(maximumDelay, baseDelay * pow(2, Double(attempt)))
        attempt += 1
        guard exponential < maximumDelay else { return maximumDelay }
        let multiplier = 1 + ((unit * 2 - 1) * jitterFraction)
        return min(maximumDelay, exponential * multiplier)
    }

    public mutating func reset() {
        attempt = 0
    }
}

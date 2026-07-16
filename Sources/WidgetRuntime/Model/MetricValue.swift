import Foundation
import HabitatCore

public enum MetricValue: Equatable, Sendable {
    case activity(AgentActivity)
    case percentage(Double)
    case date(Date)
    case durationSeconds(Int)
    case unavailable
}

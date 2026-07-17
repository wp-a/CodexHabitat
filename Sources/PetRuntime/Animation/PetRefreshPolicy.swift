import Foundation
import HabitatCore

public enum PetRefreshPolicy {
    public static func interval(
        activity: AgentActivity,
        reduceMotion: Bool
    ) -> TimeInterval? {
        guard !reduceMotion else { return nil }
        return switch activity {
        case .offline, .resting:
            nil
        case .working:
            0.125
        case .attention, .succeeded, .failed:
            0.125
        }
    }
}

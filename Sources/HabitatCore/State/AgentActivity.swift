public enum CodexThreadStatus: Sendable {
    case active
    case idle
    case systemError
    case notLoaded
}

public enum AgentActivity: String, Codable, Equatable, Sendable {
    case resting
    case working
    case attention
    case succeeded
    case failed
    case offline

    public static func codexStatus(_ status: CodexThreadStatus) -> AgentActivity {
        switch status {
        case .active:
            .working
        case .idle, .notLoaded:
            .resting
        case .systemError:
            .failed
        }
    }
}

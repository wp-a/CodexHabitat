public enum PetRenderMode: String, Codable, Equatable, Sendable {
    case auto
    case pixelated
    case smooth

    public func resolved(pixelArtHint: Bool) -> ResolvedPetRenderMode {
        switch self {
        case .auto:
            pixelArtHint ? .pixelated : .smooth
        case .pixelated:
            .pixelated
        case .smooth:
            .smooth
        }
    }
}

public enum ResolvedPetRenderMode: String, Codable, Equatable, Sendable {
    case pixelated
    case smooth
}

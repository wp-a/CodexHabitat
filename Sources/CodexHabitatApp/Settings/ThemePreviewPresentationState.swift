import Foundation

enum ThemePreviewPresentationPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed
}

enum ThemePreviewCompletion: Equatable, Sendable {
    case ignored
    case displayImage
    case clearImage
}

struct ThemePreviewPresentationState: Equatable, Sendable {
    private(set) var phase = ThemePreviewPresentationPhase.idle
    private(set) var hasPresentedImage = false
    private(set) var activeRequestID: UInt64 = 0

    var showsPlaceholder: Bool { !hasPresentedImage }
    var showsRetry: Bool { phase == .failed }

    mutating func beginRequest() -> UInt64 {
        activeRequestID &+= 1
        phase = .loading
        return activeRequestID
    }

    mutating func complete(
        requestID: UInt64,
        succeeded: Bool
    ) -> ThemePreviewCompletion {
        guard requestID == activeRequestID else { return .ignored }
        if succeeded {
            phase = .loaded
            hasPresentedImage = true
            return .displayImage
        }
        phase = .failed
        hasPresentedImage = false
        return .clearImage
    }
}

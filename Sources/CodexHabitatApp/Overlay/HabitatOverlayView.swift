import CoreGraphics
import Foundation
import HabitatCore
import PetRuntime
import SwiftUI

@MainActor
final class HabitatOverlayModel: ObservableObject {
    @Published private(set) var snapshot: HabitatSnapshot
    @Published private(set) var isAnimationActive = true
    @Published private(set) var reactionAnimation: PetAnimation?
    @Published private(set) var reactionBurstID = 0
    @Published private(set) var speechBubble: String?
    let clock: any AnimationClock
    let availableRows: Set<Int>
    let overlaySize = CGSize(width: 136, height: 144)
    let reduceMotion: Bool
    private var reactionResetTask: Task<Void, Never>?
    private var speechResetTask: Task<Void, Never>?

    init(
        clock: any AnimationClock = SystemAnimationClock(),
        initialSnapshot: HabitatSnapshot = HabitatSnapshot(),
        availableRows: Set<Int> = Set(0..<9),
        reduceMotion: Bool = false
    ) {
        snapshot = initialSnapshot
        self.clock = clock
        self.availableRows = availableRows
        self.reduceMotion = reduceMotion
    }

    deinit {
        reactionResetTask?.cancel()
        speechResetTask?.cancel()
    }

    func apply(_ nextSnapshot: HabitatSnapshot) {
        let previousActivity = snapshot.activity
        snapshot = nextSnapshot
        guard isAnimationActive, previousActivity != nextSnapshot.activity else { return }
        switch nextSnapshot.activity {
        case .working where previousActivity != .working:
            showSpeechBubble(L10n.text("Full speed coding!"))
        case .succeeded:
            showSpeechBubble(L10n.text("Done! +120 XP"))
        case .attention:
            showSpeechBubble(L10n.text("Needs your input"))
        case .failed:
            showSpeechBubble(L10n.text("Check error log"))
        case .resting, .offline, .working:
            break
        }
    }

    func setAnimationActive(_ active: Bool) {
        isAnimationActive = active
        if !active {
            reactionResetTask?.cancel()
            reactionResetTask = nil
            reactionAnimation = nil
            speechResetTask?.cancel()
            speechResetTask = nil
            speechBubble = nil
        }
    }

    func showSpeechBubble(_ message: String, durationMilliseconds: UInt64 = 2_600) {
        speechResetTask?.cancel()
        speechBubble = message
        speechResetTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(durationMilliseconds))
            guard !Task.isCancelled else { return }
            self?.speechBubble = nil
        }
    }

    func triggerReaction(
        _ animation: PetAnimation = .waving,
        speech: String? = nil,
        durationMilliseconds: UInt64 = 1_350
    ) {
        reactionResetTask?.cancel()
        reactionBurstID &+= 1
        if let speech {
            showSpeechBubble(speech, durationMilliseconds: max(durationMilliseconds, 2_400))
        }
        guard !reduceMotion, isAnimationActive else { return }
        reactionAnimation = animation
        reactionResetTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(durationMilliseconds))
            guard !Task.isCancelled else { return }
            self?.reactionAnimation = nil
        }
    }
}

struct HabitatOverlayView: View {
    @ObservedObject var model: HabitatOverlayModel
    let renderer: SpriteSheetRenderer
    var renderMode: PetRenderMode = .auto
    var pixelArtHint = false
    var isPressed = false

    var body: some View {
        PetView(
            model: model,
            renderer: renderer,
            renderMode: renderMode,
            pixelArtHint: pixelArtHint
        )
        .frame(width: model.overlaySize.width, height: model.overlaySize.height)
        .modifier(HabitatPetPressFeedback(
            isPressed: isPressed,
            reduceMotion: model.reduceMotion
        ))
    }
}

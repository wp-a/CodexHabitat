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
    let clock: any AnimationClock
    let availableRows: Set<Int>
    let overlaySize = CGSize(width: 136, height: 144)
    let reduceMotion: Bool
    private var reactionResetTask: Task<Void, Never>?

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
    }

    func apply(_ snapshot: HabitatSnapshot) {
        self.snapshot = snapshot
    }

    func setAnimationActive(_ active: Bool) {
        isAnimationActive = active
        if !active {
            reactionResetTask?.cancel()
            reactionResetTask = nil
            reactionAnimation = nil
        }
    }

    func triggerReaction(_ animation: PetAnimation = .waving, durationMilliseconds: UInt64 = 1_350) {
        reactionResetTask?.cancel()
        reactionBurstID &+= 1
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

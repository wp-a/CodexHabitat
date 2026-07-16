import CoreGraphics
import Foundation
import HabitatCore
import PetRuntime
import SwiftUI

@MainActor
final class HabitatOverlayModel: ObservableObject {
    @Published private(set) var snapshot: HabitatSnapshot
    private var animator: PetAnimator
    let overlaySize = CGSize(width: 160, height: 180)
    let reduceMotion: Bool

    init(
        clock: any AnimationClock = SystemAnimationClock(),
        initialSnapshot: HabitatSnapshot = HabitatSnapshot(),
        availableRows: Set<Int> = Set(0..<9),
        reduceMotion: Bool = false
    ) {
        snapshot = initialSnapshot
        animator = PetAnimator(
            clock: clock,
            initialActivity: initialSnapshot.activity,
            availableRows: availableRows,
            reduceMotion: reduceMotion
        )
        self.reduceMotion = reduceMotion
    }

    func apply(_ snapshot: HabitatSnapshot) {
        self.snapshot = snapshot
        _ = animator.update(activity: snapshot.activity)
    }

    func currentFrame() -> PetFrame {
        animator.currentFrame()
    }
}

struct HabitatOverlayView: View {
    @ObservedObject var model: HabitatOverlayModel
    let renderer: SpriteSheetRenderer
    var renderMode: PetRenderMode = .auto
    var pixelArtHint = false

    var body: some View {
        PetView(
            model: model,
            renderer: renderer,
            renderMode: renderMode,
            pixelArtHint: pixelArtHint
        )
        .frame(width: model.overlaySize.width, height: model.overlaySize.height)
    }
}

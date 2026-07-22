import CoreGraphics
import Foundation
import HabitatCore
import PetRuntime
import SwiftUI

@MainActor
final class HabitatOverlayModel: ObservableObject {
    @Published private(set) var snapshot: HabitatSnapshot
    @Published private(set) var isAnimationActive = true
    let clock: any AnimationClock
    let availableRows: Set<Int>
    let overlaySize = CGSize(width: 136, height: 144)
    let reduceMotion: Bool

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

    func apply(_ snapshot: HabitatSnapshot) {
        self.snapshot = snapshot
    }

    func setAnimationActive(_ active: Bool) {
        isAnimationActive = active
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

import PetRuntime
import SwiftUI

struct PetView: View {
    @ObservedObject var model: HabitatOverlayModel
    let renderer: SpriteSheetRenderer
    let renderMode: PetRenderMode
    let pixelArtHint: Bool

    var body: some View {
        PetSpriteView(
            activity: model.isAnimationActive ? model.snapshot.activity : .resting,
            renderer: renderer,
            renderMode: renderMode,
            pixelArtHint: pixelArtHint,
            clock: model.clock,
            availableRows: model.availableRows,
            reduceMotion: model.reduceMotion
        )
        .frame(width: model.overlaySize.width, height: model.overlaySize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("Codex Habitat pet"))
    }
}

struct HabitatPetPressFeedback: ViewModifier {
    let isPressed: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1, anchor: .bottom)
            .opacity(isPressed ? 0.82 : 1)
    }
}

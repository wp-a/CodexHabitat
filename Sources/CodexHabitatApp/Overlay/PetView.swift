import PetRuntime
import SwiftUI

struct PetView: View {
    @ObservedObject var model: HabitatOverlayModel
    let renderer: SpriteSheetRenderer
    let renderMode: PetRenderMode
    let pixelArtHint: Bool

    var body: some View {
        PetSpriteView(
            activity: model.snapshot.activity,
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

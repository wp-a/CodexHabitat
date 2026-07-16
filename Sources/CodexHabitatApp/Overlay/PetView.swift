import PetRuntime
import SwiftUI

struct PetView: View {
    @ObservedObject var model: HabitatOverlayModel
    let renderer: SpriteSheetRenderer
    let renderMode: PetRenderMode
    let pixelArtHint: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: model.reduceMotion)) { _ in
            frameView(model.currentFrame())
        }
        .frame(width: model.overlaySize.width, height: model.overlaySize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Codex Habitat pet")
    }

    @ViewBuilder
    private func frameView(_ frame: PetFrame) -> some View {
        if let image = renderer.frame(frame) {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .interpolation(interpolation)
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var interpolation: Image.Interpolation {
        renderMode.resolved(pixelArtHint: pixelArtHint) == .pixelated ? .none : .high
    }
}

import HabitatCore
import PetRuntime
import SwiftUI

struct PetView: View {
    @ObservedObject var model: HabitatOverlayModel
    let renderer: SpriteSheetRenderer
    let renderMode: PetRenderMode
    let pixelArtHint: Bool
    var accentColor: Color = .cyan

    var body: some View {
        ZStack {
            ambientAura
                .allowsHitTesting(false)

            PetSpriteView(
                activity: model.isAnimationActive ? model.snapshot.activity : .resting,
                requestedAnimation: model.isAnimationActive ? model.reactionAnimation : nil,
                renderer: renderer,
                renderMode: renderMode,
                pixelArtHint: pixelArtHint,
                clock: model.clock,
                availableRows: model.availableRows,
                reduceMotion: model.reduceMotion
            )
            .frame(width: model.overlaySize.width, height: model.overlaySize.height)

            if model.reactionAnimation != nil, !model.reduceMotion {
                PetReactionSparkleBurst(id: model.reactionBurstID, tint: accentColor)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: model.overlaySize.width, height: model.overlaySize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("Codex Habitat pet"))
    }

    @ViewBuilder
    private var ambientAura: some View {
        let tint = auraColor
        RadialGradient(
            colors: [
                tint.opacity(auraOpacity),
                tint.opacity(auraOpacity * 0.28),
                .clear,
            ],
            center: .init(x: 0.5, y: 0.62),
            startRadius: 4,
            endRadius: 56
        )
    }

    private var auraColor: Color {
        switch model.snapshot.activity {
        case .working: accentColor
        case .succeeded: .green
        case .attention: .orange
        case .failed: .red
        case .resting, .offline: accentColor
        }
    }

    private var auraOpacity: Double {
        if model.reactionAnimation != nil {
            return 0.34
        }
        return switch model.snapshot.activity {
        case .working: 0.28
        case .succeeded: 0.30
        case .attention: 0.24
        case .failed: 0.26
        case .resting: 0.12
        case .offline: 0.05
        }
    }
}

private struct PetReactionSparkleBurst: View {
    let id: Int
    let tint: Color
    @State private var popped = false

    var body: some View {
        ZStack {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .offset(x: popped ? -38 : -20, y: popped ? -36 : -14)
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.pink)
                .offset(x: popped ? 36 : 18, y: popped ? -40 : -16)
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.yellow)
                .offset(x: popped ? 30 : 14, y: popped ? 8 : 2)
        }
        .opacity(popped ? 0.95 : 0.2)
        .scaleEffect(popped ? 1.06 : 0.65)
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.62)) {
                popped = true
            }
        }
        .id(id)
    }
}

struct HabitatPetPressFeedback: ViewModifier {
    let isPressed: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: isPressed && !reduceMotion ? 1.05 : 1,
                y: isPressed && !reduceMotion ? 0.92 : 1,
                anchor: .bottom
            )
            .opacity(isPressed ? 0.90 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.62),
                value: isPressed
            )
    }
}

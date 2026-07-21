import SwiftUI

struct HabitatInteractionVisualState: Equatable, Sendable {
    let scale: Double
    let overlayOpacity: Double
    let borderWidth: Double
    let layoutInset: Double

    static func resolve(
        isPressed: Bool,
        isHovered: Bool,
        isSelected: Bool,
        isFocused: Bool,
        reduceMotion: Bool = false
    ) -> Self {
        var overlayOpacity = 0.0
        if isHovered {
            overlayOpacity += 0.05
        }
        if isSelected {
            overlayOpacity += 0.08
        }
        if isPressed {
            overlayOpacity += 0.03
        }

        return Self(
            scale: isPressed && !reduceMotion ? 0.985 : 1,
            overlayOpacity: min(overlayOpacity, 0.16),
            borderWidth: isFocused ? 2 : (isSelected ? 1 : 0),
            layoutInset: 0
        )
    }
}

struct HabitatPressButtonStyle: ButtonStyle {
    let radius: Double

    @Environment(\.habitatAccessibility) private var accessibility
    @Environment(\.habitatThemeAccent) private var themeAccent

    init(radius: Double = HabitatDesignMetrics.smallControlRadius) {
        self.radius = radius
    }

    func makeBody(configuration: Configuration) -> some View {
        let state = HabitatInteractionVisualState.resolve(
            isPressed: configuration.isPressed,
            isHovered: false,
            isSelected: false,
            isFocused: false,
            reduceMotion: accessibility.reduceMotion
        )

        configuration.label
            .scaleEffect(state.scale)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(themeAccent.selection.color.opacity(state.overlayOpacity))
                    .allowsHitTesting(false)
            }
            .animation(
                HabitatMotion.resolve(.press, reduceMotion: accessibility.reduceMotion).animation,
                value: configuration.isPressed
            )
    }
}

private struct HabitatHoverStyle: ViewModifier {
    let radius: Double

    @Environment(\.habitatAccessibility) private var accessibility
    @Environment(\.habitatThemeAccent) private var themeAccent
    @State private var isHovered = false

    func body(content: Content) -> some View {
        let state = HabitatInteractionVisualState.resolve(
            isPressed: false,
            isHovered: isHovered,
            isSelected: false,
            isFocused: false
        )

        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(themeAccent.selection.color.opacity(state.overlayOpacity))
                    .allowsHitTesting(false)
            }
            .onHover { isHovered = $0 }
            .animation(
                HabitatMotion.resolve(
                    .selection,
                    reduceMotion: accessibility.reduceMotion
                ).animation,
                value: isHovered
            )
    }
}

private struct HabitatSelectedStyle: ViewModifier {
    let isSelected: Bool
    let radius: Double

    @Environment(\.habitatAccessibility) private var accessibility
    @Environment(\.habitatThemeAccent) private var themeAccent

    func body(content: Content) -> some View {
        let state = HabitatInteractionVisualState.resolve(
            isPressed: false,
            isHovered: false,
            isSelected: isSelected,
            isFocused: false
        )
        let borderWidth = accessibility.distinguishesStateWithoutColor && isSelected
            ? 2.0 : state.borderWidth

        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(themeAccent.selection.color.opacity(state.overlayOpacity))
                    .stroke(
                        themeAccent.selection.color.opacity(
                            isSelected ? 0.72 : 0
                        ),
                        lineWidth: borderWidth
                    )
                    .allowsHitTesting(false)
            }
            .animation(
                HabitatMotion.resolve(
                    .selection,
                    reduceMotion: accessibility.reduceMotion
                ).animation,
                value: isSelected
            )
    }
}

private struct HabitatFocusStyle: ViewModifier {
    let isFocused: Bool
    let radius: Double

    @Environment(\.habitatAccessibility) private var accessibility
    @Environment(\.habitatThemeAccent) private var themeAccent

    func body(content: Content) -> some View {
        let state = HabitatInteractionVisualState.resolve(
            isPressed: false,
            isHovered: false,
            isSelected: false,
            isFocused: isFocused
        )

        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        themeAccent.focus.color.opacity(isFocused ? 0.92 : 0),
                        lineWidth: state.borderWidth
                    )
                    .allowsHitTesting(false)
            }
            .animation(
                HabitatMotion.resolve(
                    .selection,
                    reduceMotion: accessibility.reduceMotion
                ).animation,
                value: isFocused
            )
    }
}

extension HabitatResolvedMotion {
    fileprivate var animation: Animation? {
        switch kind {
        case .immediate:
            nil
        case .easeOut, .crossFade:
            .easeOut(duration: duration)
        case .spring:
            .spring(response: duration, dampingFraction: 0.84)
        }
    }
}

extension View {
    func habitatHoverStyle(
        radius: Double = HabitatDesignMetrics.smallControlRadius
    ) -> some View {
        modifier(HabitatHoverStyle(radius: radius))
    }

    func habitatSelectedStyle(
        _ isSelected: Bool,
        radius: Double = HabitatDesignMetrics.smallControlRadius
    ) -> some View {
        modifier(HabitatSelectedStyle(isSelected: isSelected, radius: radius))
    }

    func habitatFocusStyle(
        _ isFocused: Bool,
        radius: Double = HabitatDesignMetrics.smallControlRadius
    ) -> some View {
        modifier(HabitatFocusStyle(isFocused: isFocused, radius: radius))
    }
}

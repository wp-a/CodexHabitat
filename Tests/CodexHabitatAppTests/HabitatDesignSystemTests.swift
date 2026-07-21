import Testing
@testable import CodexHabitatApp

@Suite("HabitatDesignSystemTests")
struct HabitatDesignSystemTests {
    @Test
    func designMetricsRemainCompactAndDeliberate() {
        #expect(HabitatDesignMetrics.spacing == [4, 8, 12, 16, 20, 24, 32])
        #expect(HabitatDesignMetrics.smallControlRadius == 5)
        #expect(HabitatDesignMetrics.cardRadius == 8)
        #expect(HabitatDesignMetrics.previewRadius == 10)
        #expect(HabitatDesignMetrics.compactControlHeight == 28)
        #expect(HabitatDesignMetrics.standardControlHeight == 32)
        #expect(HabitatDesignMetrics.prominentControlHeight == 36)
        #expect(HabitatMotion.panelResponse >= 0.30)
        #expect(HabitatMotion.panelResponse <= 0.40)
    }

    @Test
    func reducedMotionReplacesMovementWithTheSharedCrossFade() {
        let standard = HabitatMotion.resolve(.panel, reduceMotion: false)
        let reduced = HabitatMotion.resolve(.panel, reduceMotion: true)

        #expect(standard.kind == .spring)
        #expect(standard.duration == HabitatMotion.panelResponse)
        #expect(reduced.kind == .crossFade)
        #expect(reduced.duration == HabitatMotion.reducedCrossFadeDuration)
        #expect(HabitatMotion.resolve(.press, reduceMotion: true).kind == .immediate)
    }

    @Test
    func accessibilityPreferencesResolveDeterministically() {
        let first = HabitatAccessibilityResolution.resolve(
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
            differentiateWithoutColor: true
        )
        let second = HabitatAccessibilityResolution.resolve(
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
            differentiateWithoutColor: true
        )

        #expect(first == second)
        #expect(first.reduceMotion)
        #expect(first.usesOpaqueSurfaces)
        #expect(first.boundaryOpacity == 0.28)
        #expect(first.distinguishesStateWithoutColor)
    }

    @Test
    func materialAndEmphasisRolesStaySemanticAndComplete() {
        #expect(HabitatMaterialRole.allCases == [
            .sidebar, .toolbar, .content, .inspector, .popover, .focusedControl,
        ])
        #expect(HabitatEmphasis.allCases == [
            .quiet, .normal, .selected, .focused, .warning, .destructive, .success,
        ])
    }

    @Test
    func themeAccentResolutionIsBoundedAndContrastSafe() throws {
        let lightSurface = try #require(HabitatSRGBColor(hex: "#FFFFFF"))
        let first = HabitatThemeAccent.resolve(
            accentHex: "#FDFDFD",
            secondaryHex: "#8A7CFF",
            appearance: .light,
            increaseContrast: false
        )
        let second = HabitatThemeAccent.resolve(
            accentHex: "#FDFDFD",
            secondaryHex: "#8A7CFF",
            appearance: .light,
            increaseContrast: false
        )

        #expect(first == second)
        #expect(first.selection.contrastRatio(against: lightSurface) >= 3)
        #expect(first.focus.contrastRatio(against: lightSurface) >= 4.5)
        #expect(first.allComponentsAreBounded)
    }

    @Test
    func invalidThemeColorsUseStableSystemLikeFallbacks() throws {
        let resolved = HabitatThemeAccent.resolve(
            accentHex: "not-a-color",
            secondaryHex: "#XYZXYZ",
            appearance: .dark,
            increaseContrast: false
        )

        #expect(resolved.accent == HabitatSRGBColor(hex: "#0A84FF"))
        #expect(resolved.secondary == HabitatSRGBColor(hex: "#64D2FF"))
    }

    @Test
    func interactionFeedbackDoesNotRequestLayoutChanges() {
        let idle = HabitatInteractionVisualState.resolve(
            isPressed: false,
            isHovered: false,
            isSelected: false,
            isFocused: false
        )
        let active = HabitatInteractionVisualState.resolve(
            isPressed: true,
            isHovered: true,
            isSelected: true,
            isFocused: true
        )

        #expect(idle.layoutInset == 0)
        #expect(active.layoutInset == 0)
        #expect(active.scale == 0.985)
        #expect(active.overlayOpacity > idle.overlayOpacity)
        #expect(active.borderWidth == 2)
    }

    @Test
    func reducedMotionPressFeedbackUsesColorWithoutScaling() {
        let reduced = HabitatInteractionVisualState.resolve(
            isPressed: true,
            isHovered: false,
            isSelected: false,
            isFocused: false,
            reduceMotion: true
        )

        #expect(reduced.scale == 1)
        #expect(reduced.overlayOpacity > 0)
    }
}

import Foundation
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
    func reducedTransparencyUsesAnExplicitOpaqueBackingForEverySurfaceRole() {
        let plans = HabitatMaterialRole.allCases.map {
            HabitatSurfacePlan.resolve(role: $0, reduceTransparency: true)
        }

        #expect(plans.allSatisfy { !$0.usesMaterial })
        #expect(plans.allSatisfy { $0.usesExplicitOpaqueBacking })
        #expect(plans.allSatisfy { $0.opaqueBackingAlpha == 1 })
    }

    @Test
    func nativeSurfacesDoNotInheritTheSelectedThemesDecorativeTint() {
        let plans = HabitatMaterialRole.allCases.map {
            HabitatSurfacePlan.resolve(role: $0, reduceTransparency: true)
        }

        #expect(plans.allSatisfy { $0.themeTint == .none })
        #expect(plans.allSatisfy { $0.themeTintOpacity == 0 })
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
        #expect(first.selection.contrastRatio(against: lightSurface) >= 4.5)
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
    func eightDigitThemeColorsCompositeAgainstTheLightAppearance() throws {
        let parsedAccent = try #require(HabitatSRGBColor(hex: "#FF000080"))
        #expect(abs(parsedAccent.alpha - (128.0 / 255)) < 0.000_001)

        let resolved = HabitatThemeAccent.resolve(
            accentHex: "#FF000080",
            secondaryHex: "#0000FF40",
            appearance: .light,
            increaseContrast: false
        )
        let lightSurface = try #require(HabitatSRGBColor(hex: "#FFFFFF"))

        #expect(abs(resolved.accent.red - 1) < 0.000_001)
        #expect(abs(resolved.accent.green - (127.0 / 255)) < 0.000_001)
        #expect(abs(resolved.accent.blue - (127.0 / 255)) < 0.000_001)
        #expect(abs(resolved.secondary.red - (191.0 / 255)) < 0.000_001)
        #expect(abs(resolved.secondary.green - (191.0 / 255)) < 0.000_001)
        #expect(abs(resolved.secondary.blue - 1) < 0.000_001)
        #expect(resolved.accent.alpha == 1)
        #expect(resolved.secondary.alpha == 1)
        #expect(resolved.accent != HabitatSRGBColor(hex: "#0A84FF"))
        #expect(resolved.selection.contrastRatio(against: lightSurface) >= 4.5)
        #expect(resolved.focus.contrastRatio(against: lightSurface) >= 4.5)
    }

    @Test
    func eightDigitThemeColorsHonorDarkIncreasedContrast() throws {
        let resolved = HabitatThemeAccent.resolve(
            accentHex: "#FF000080",
            secondaryHex: "#00FF0080",
            appearance: .dark,
            increaseContrast: true
        )
        let darkSurface = try #require(HabitatSRGBColor(hex: "#1C1C1E"))
        let alpha = 128.0 / 255

        #expect(abs(resolved.accent.red - (alpha + darkSurface.red * (1 - alpha))) < 0.000_001)
        #expect(abs(resolved.accent.green - (darkSurface.green * (1 - alpha))) < 0.000_001)
        #expect(abs(resolved.accent.blue - (darkSurface.blue * (1 - alpha))) < 0.000_001)
        #expect(abs(resolved.secondary.red - (darkSurface.red * (1 - alpha))) < 0.000_001)
        #expect(abs(resolved.secondary.green - (alpha + darkSurface.green * (1 - alpha))) < 0.000_001)
        #expect(abs(resolved.secondary.blue - (darkSurface.blue * (1 - alpha))) < 0.000_001)
        #expect(resolved.selection.contrastRatio(against: darkSurface) >= 4.5)
        #expect(resolved.focus.contrastRatio(against: darkSurface) >= 7)
        #expect(resolved.allComponentsAreBounded)
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

    @Test
    func designEnvironmentLeavesNativeControlTintToMacOS() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/CodexHabitatApp/Design/HabitatDesignSystem.swift"
            ),
            encoding: .utf8
        )

        #expect(!source.contains(".tint(accent.selection.color)"))
    }
}

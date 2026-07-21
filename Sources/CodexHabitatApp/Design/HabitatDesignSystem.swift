import AppKit
import Foundation
import SwiftUI

enum HabitatDesignMetrics {
    static let spacing: [Double] = [4, 8, 12, 16, 20, 24, 32]

    static let spaceXS = 4.0
    static let spaceS = 8.0
    static let spaceM = 12.0
    static let spaceL = 16.0
    static let spaceXL = 20.0
    static let spaceXXL = 24.0
    static let spaceSection = 32.0

    static let smallControlRadius = 5.0
    static let cardRadius = 8.0
    static let previewRadius = 10.0

    static let compactControlHeight = 28.0
    static let standardControlHeight = 32.0
    static let prominentControlHeight = 36.0
}

enum HabitatMotionRole: Equatable, Sendable {
    case press
    case selection
    case navigation
    case panel
}

enum HabitatMotionKind: Equatable, Sendable {
    case immediate
    case easeOut
    case spring
    case crossFade
}

struct HabitatResolvedMotion: Equatable, Sendable {
    let kind: HabitatMotionKind
    let duration: Double
}

enum HabitatMotion {
    static let pressDuration = 0.09
    static let selectionDuration = 0.18
    static let navigationDuration = 0.20
    static let panelResponse = 0.32
    static let reducedCrossFadeDuration = 0.12

    static func resolve(
        _ role: HabitatMotionRole,
        reduceMotion: Bool
    ) -> HabitatResolvedMotion {
        if reduceMotion {
            return role == .press
                ? HabitatResolvedMotion(kind: .immediate, duration: 0)
                : HabitatResolvedMotion(kind: .crossFade, duration: reducedCrossFadeDuration)
        }

        return switch role {
        case .press:
            HabitatResolvedMotion(kind: .easeOut, duration: pressDuration)
        case .selection:
            HabitatResolvedMotion(kind: .easeOut, duration: selectionDuration)
        case .navigation:
            HabitatResolvedMotion(kind: .easeOut, duration: navigationDuration)
        case .panel:
            HabitatResolvedMotion(kind: .spring, duration: panelResponse)
        }
    }
}

struct HabitatAccessibilityResolution: Equatable, Sendable {
    let reduceMotion: Bool
    let usesOpaqueSurfaces: Bool
    let boundaryOpacity: Double
    let distinguishesStateWithoutColor: Bool

    static let standard = resolve(
        reduceMotion: false,
        reduceTransparency: false,
        increaseContrast: false,
        differentiateWithoutColor: false
    )

    static func resolve(
        reduceMotion: Bool,
        reduceTransparency: Bool,
        increaseContrast: Bool,
        differentiateWithoutColor: Bool
    ) -> Self {
        Self(
            reduceMotion: reduceMotion,
            usesOpaqueSurfaces: reduceTransparency,
            boundaryOpacity: increaseContrast ? 0.28 : 0.14,
            distinguishesStateWithoutColor: differentiateWithoutColor
        )
    }
}

enum HabitatMaterialRole: CaseIterable, Equatable, Sendable {
    case sidebar
    case toolbar
    case content
    case inspector
    case popover
    case focusedControl
}

enum HabitatSurfaceSemanticColor: Equatable, Sendable {
    case window
    case underPage
    case control
}

enum HabitatSurfaceThemeTint: Equatable, Sendable {
    case none
    case selection
    case secondary
}

struct HabitatSurfacePlan: Equatable, Sendable {
    let role: HabitatMaterialRole
    let usesMaterial: Bool
    let opaqueBackingAlpha: Double
    let semanticColor: HabitatSurfaceSemanticColor
    let themeTint: HabitatSurfaceThemeTint
    let themeTintOpacity: Double

    static func resolve(
        role: HabitatMaterialRole,
        reduceTransparency: Bool
    ) -> Self {
        let usesMaterial = !reduceTransparency && role != .content
        let semanticColor: HabitatSurfaceSemanticColor = switch role {
        case .sidebar:
            .underPage
        case .toolbar, .content, .popover:
            .window
        case .inspector, .focusedControl:
            .control
        }
        let themeTint: HabitatSurfaceThemeTint = switch role {
        case .content:
            .secondary
        case .focusedControl:
            .selection
        default:
            .none
        }
        let themeTintOpacity = switch themeTint {
        case .none:
            0.0
        case .selection:
            0.14
        case .secondary:
            0.025
        }

        return Self(
            role: role,
            usesMaterial: usesMaterial,
            opaqueBackingAlpha: usesMaterial ? 0 : 1,
            semanticColor: semanticColor,
            themeTint: themeTint,
            themeTintOpacity: themeTintOpacity
        )
    }

    var usesExplicitOpaqueBacking: Bool {
        opaqueBackingAlpha == 1
    }
}

enum HabitatEmphasis: CaseIterable, Equatable, Sendable {
    case quiet
    case normal
    case selected
    case focused
    case warning
    case destructive
    case success
}

enum HabitatColorAppearance: Equatable, Sendable {
    case light
    case dark
}

struct HabitatSRGBColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    init?(hex: String) {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard [6, 8].contains(digits.count), let packed = UInt64(digits, radix: 16) else {
            return nil
        }
        let rgb = digits.count == 8 ? packed >> 8 : packed
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            alpha: digits.count == 8 ? Double(packed & 0xFF) / 255 : 1
        )
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var componentsAreBounded: Bool {
        (0...1).contains(red) && (0...1).contains(green) && (0...1).contains(blue)
            && (0...1).contains(alpha)
    }

    func contrastRatio(against other: Self) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func composited(over background: Self) -> Self {
        let outputAlpha = alpha + background.alpha * (1 - alpha)
        guard outputAlpha > 0 else {
            return Self(red: 0, green: 0, blue: 0, alpha: 0)
        }
        return Self(
            red: (red * alpha + background.red * background.alpha * (1 - alpha))
                / outputAlpha,
            green: (green * alpha + background.green * background.alpha * (1 - alpha))
                / outputAlpha,
            blue: (blue * alpha + background.blue * background.alpha * (1 - alpha))
                / outputAlpha,
            alpha: outputAlpha
        )
    }

    fileprivate func ensuringContrast(
        _ minimumContrast: Double,
        against background: Self
    ) -> Self {
        guard contrastRatio(against: background) < minimumContrast else {
            return self
        }

        let black = Self(red: 0, green: 0, blue: 0)
        let white = Self(red: 1, green: 1, blue: 1)
        let target = black.contrastRatio(against: background)
            >= white.contrastRatio(against: background) ? black : white
        guard target.contrastRatio(against: background) >= minimumContrast else {
            return target
        }

        var lowerBound = 0.0
        var upperBound = 1.0
        for _ in 0..<24 {
            let amount = (lowerBound + upperBound) / 2
            if mixed(toward: target, amount: amount)
                .contrastRatio(against: background) >= minimumContrast {
                upperBound = amount
            } else {
                lowerBound = amount
            }
        }
        return mixed(toward: target, amount: upperBound)
    }

    private var relativeLuminance: Double {
        0.2126 * Self.linearized(red)
            + 0.7152 * Self.linearized(green)
            + 0.0722 * Self.linearized(blue)
    }

    private func mixed(toward other: Self, amount: Double) -> Self {
        let boundedAmount = Self.clamp(amount)
        return Self(
            red: red + ((other.red - red) * boundedAmount),
            green: green + ((other.green - green) * boundedAmount),
            blue: blue + ((other.blue - blue) * boundedAmount),
            alpha: alpha + ((other.alpha - alpha) * boundedAmount)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func linearized(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

struct HabitatThemeAccent: Equatable, Sendable {
    let accent: HabitatSRGBColor
    let secondary: HabitatSRGBColor
    let selection: HabitatSRGBColor
    let focus: HabitatSRGBColor

    static let defaultValue = resolve(
        accentHex: "#0A84FF",
        secondaryHex: "#64D2FF",
        appearance: .light,
        increaseContrast: false
    )

    static func resolve(
        accentHex: String,
        secondaryHex: String,
        appearance: HabitatColorAppearance,
        increaseContrast: Bool
    ) -> Self {
        let background = appearance == .light
            ? HabitatSRGBColor(red: 1, green: 1, blue: 1)
            : HabitatSRGBColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
        let accent = (HabitatSRGBColor(hex: accentHex)
            ?? HabitatSRGBColor(red: 10 / 255, green: 132 / 255, blue: 1))
            .composited(over: background)
        let secondary = (HabitatSRGBColor(hex: secondaryHex)
            ?? HabitatSRGBColor(red: 100 / 255, green: 210 / 255, blue: 1))
            .composited(over: background)
        let selectionContrast = increaseContrast ? 4.5 : 3.0
        let focusContrast = increaseContrast ? 7.0 : 4.5

        return Self(
            accent: accent,
            secondary: secondary,
            selection: accent.ensuringContrast(selectionContrast, against: background),
            focus: accent.ensuringContrast(focusContrast, against: background)
        )
    }

    var allComponentsAreBounded: Bool {
        [accent, secondary, selection, focus].allSatisfy(\.componentsAreBounded)
    }
}

private struct HabitatThemeAccentKey: EnvironmentKey {
    static let defaultValue = HabitatThemeAccent.defaultValue
}

private struct HabitatAccessibilityResolutionKey: EnvironmentKey {
    static let defaultValue = HabitatAccessibilityResolution.standard
}

extension EnvironmentValues {
    var habitatThemeAccent: HabitatThemeAccent {
        get { self[HabitatThemeAccentKey.self] }
        set { self[HabitatThemeAccentKey.self] = newValue }
    }

    var habitatAccessibility: HabitatAccessibilityResolution {
        get { self[HabitatAccessibilityResolutionKey.self] }
        set { self[HabitatAccessibilityResolutionKey.self] = newValue }
    }
}

struct HabitatSurface: View {
    let role: HabitatMaterialRole

    @Environment(\.habitatAccessibility) private var accessibility
    @Environment(\.habitatThemeAccent) private var themeAccent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let plan = HabitatSurfacePlan.resolve(
            role: role,
            reduceTransparency: accessibility.usesOpaqueSurfaces
        )

        ZStack {
            surface(plan: plan)
            if plan.themeTint != .none {
                themeTint(plan.themeTint).opacity(plan.themeTintOpacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func surface(plan: HabitatSurfacePlan) -> some View {
        if plan.usesMaterial {
            Rectangle().fill(material)
        } else {
            ZStack {
                explicitOpaqueBacking
                semanticColor(plan.semanticColor)
            }
        }
    }

    private var explicitOpaqueBacking: Color {
        colorScheme == .dark
            ? HabitatSRGBColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255).color
            : HabitatSRGBColor(red: 1, green: 1, blue: 1).color
    }

    private func semanticColor(_ semanticColor: HabitatSurfaceSemanticColor) -> Color {
        switch semanticColor {
        case .window:
            Color(nsColor: .windowBackgroundColor)
        case .underPage:
            Color(nsColor: .underPageBackgroundColor)
        case .control:
            Color(nsColor: .controlBackgroundColor)
        }
    }

    private func themeTint(_ themeTint: HabitatSurfaceThemeTint) -> Color {
        switch themeTint {
        case .none:
            .clear
        case .selection:
            themeAccent.selection.color
        case .secondary:
            themeAccent.secondary.color
        }
    }

    private var material: Material {
        switch role {
        case .sidebar:
            .thickMaterial
        case .toolbar:
            .ultraThinMaterial
        case .content:
            .ultraThinMaterial
        case .inspector:
            .thinMaterial
        case .popover:
            .regularMaterial
        case .focusedControl:
            .thinMaterial
        }
    }
}

extension HabitatEmphasis {
    func color(themeAccent: HabitatThemeAccent) -> Color {
        switch self {
        case .quiet:
            Color.secondary.opacity(0.72)
        case .normal:
            Color.primary
        case .selected:
            themeAccent.selection.color
        case .focused:
            themeAccent.focus.color
        case .warning:
            Color(nsColor: .systemOrange)
        case .destructive:
            Color(nsColor: .systemRed)
        case .success:
            Color(nsColor: .systemGreen)
        }
    }
}

private struct HabitatDesignEnvironmentModifier: ViewModifier {
    let accentHex: String
    let secondaryHex: String

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        let accessibility = HabitatAccessibilityResolution.resolve(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
            differentiateWithoutColor: differentiateWithoutColor
        )
        let accent = HabitatThemeAccent.resolve(
            accentHex: accentHex,
            secondaryHex: secondaryHex,
            appearance: colorScheme == .dark ? .dark : .light,
            increaseContrast: colorSchemeContrast == .increased
        )

        content
            .tint(accent.selection.color)
            .environment(\.habitatAccessibility, accessibility)
            .environment(\.habitatThemeAccent, accent)
    }
}

extension View {
    func habitatDesignEnvironment(
        accentHex: String,
        secondaryHex: String
    ) -> some View {
        modifier(HabitatDesignEnvironmentModifier(
            accentHex: accentHex,
            secondaryHex: secondaryHex
        ))
    }
}

import Foundation
import HabitatCore
import SwiftUI

enum ThemeTreatmentPreviewRoute: Equatable, Hashable, Sendable {
    case home
    case task
}

struct ThemeTreatmentPreviewModel: Equatable, Sendable {
    let styleFamily: HabitatThemeStyleFamily
    let artFocus: HabitatThemeFocalPoint
    let safeSide: HabitatThemeSafeSide
    let density: HabitatThemeDensity
    let homeMode: HabitatThemeHomeMode
    let taskMode: HabitatThemeTaskMode
    let chromeMaterial: HabitatThemeChromeMaterial
    let homeStrength: Double
    let taskStrength: Double
    let sidebarOpacity: Double
    let headerOpacity: Double
    let composerOpacity: Double
    let blurRadius: Double
    let surfaceHex: String
    let panelHex: String
    let panelAltHex: String
    let textHex: String
    let accentHex: String

    init(theme: HabitatThemeDescriptor) {
        self.init(
            appearance: theme.appearance,
            surfaceHex: theme.surfaceHex,
            panelHex: theme.panelHex,
            panelAltHex: theme.panelAltHex,
            textHex: theme.textHex,
            accentHex: theme.accentHex
        )
    }

    init(
        appearance: HabitatThemeAppearance,
        surfaceHex: String,
        panelHex: String,
        panelAltHex: String,
        textHex: String,
        accentHex: String
    ) {
        styleFamily = appearance.styleFamily
        artFocus = appearance.artFocus
        safeSide = appearance.safeSide
        density = appearance.density
        homeMode = appearance.resolvedHomeMode
        taskMode = appearance.resolvedTaskMode
        chromeMaterial = appearance.resolvedChromeMaterial
        homeStrength = appearance.resolvedHomeStrength
        taskStrength = appearance.resolvedTaskStrength
        sidebarOpacity = appearance.resolvedSidebarOpacity
        headerOpacity = appearance.resolvedHeaderOpacity
        composerOpacity = appearance.resolvedComposerOpacity
        blurRadius = appearance.blurRadius
        self.surfaceHex = surfaceHex
        self.panelHex = panelHex
        self.panelAltHex = panelAltHex
        self.textHex = textHex
        self.accentHex = accentHex
    }

    var treatmentSignature: String {
        [
            styleFamily.rawValue,
            homeMode.rawValue,
            taskMode.rawValue,
            chromeMaterial.rawValue,
            safeSide.rawValue,
            density.rawValue,
            Self.number(homeStrength),
            Self.number(taskStrength),
            Self.number(sidebarOpacity),
            Self.number(headerOpacity),
            Self.number(composerOpacity),
            Self.number(blurRadius),
        ].joined(separator: "|")
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

struct ThemeTreatmentPreview: View {
    let model: ThemeTreatmentPreviewModel
    let imageURL: URL?
    let symbol: String
    var route = ThemeTreatmentPreviewRoute.home
    var height = 100.0
    @State private var image: CGImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(habitatHex: model.surfaceHex)
                treatmentArtwork(in: geometry.size)
                chrome(in: geometry.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: outerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: outerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .task(id: imageURL) {
            let loadedImage = await ThemePreviewStore.shared.image(at: imageURL)
            guard !Task.isCancelled else { return }
            image = loadedImage
        }
    }

    @ViewBuilder
    private func treatmentArtwork(in size: CGSize) -> some View {
        if route == .home, model.homeMode == .framed {
            let sidebarWidth = size.width * sidebarFraction
            let artworkSize = CGSize(
                width: max(1, size.width - sidebarWidth - 12),
                height: max(1, size.height - 12)
            )
            HStack(spacing: 0) {
                Color.clear.frame(width: sidebarWidth + 6)
                artworkLayers(in: artworkSize)
                    .frame(width: artworkSize.width, height: artworkSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: innerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: innerRadius)
                            .stroke(
                                Color(habitatHex: model.accentHex).opacity(0.48),
                                lineWidth: 1
                            )
                    }
            }
            .frame(width: size.width, height: size.height, alignment: .leading)
        } else {
            artworkLayers(in: size)
        }
    }

    private func artworkLayers(in size: CGSize) -> some View {
        ZStack {
            artwork(in: size)
            Color(habitatHex: model.surfaceHex)
                .opacity(1 - artStrength)
            readabilityScrim
        }
    }

    @ViewBuilder
    private func artwork(in size: CGSize) -> some View {
        if artStrength == 0 {
            Color(habitatHex: model.surfaceHex)
        } else if let image {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .scaleEffect(1.16)
                .offset(
                    x: (0.5 - model.artFocus.x) * size.width * 0.18,
                    y: (0.5 - model.artFocus.y) * size.height * 0.18
                )
                .clipped()
        } else {
            Color(habitatHex: model.panelAltHex)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(habitatHex: model.accentHex))
                }
        }
    }

    @ViewBuilder
    private var readabilityScrim: some View {
        let surface = Color(habitatHex: model.surfaceHex)
        switch model.safeSide {
        case .leading:
            LinearGradient(
                colors: [surface.opacity(0.84), surface.opacity(0.36), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .trailing:
            LinearGradient(
                colors: [.clear, surface.opacity(0.36), surface.opacity(0.84)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .center:
            RadialGradient(
                colors: [surface.opacity(0.68), surface.opacity(0.10), .clear],
                center: .center,
                startRadius: 2,
                endRadius: 86
            )
        case .none:
            Color.clear
        }
    }

    private func chrome(in size: CGSize) -> some View {
        let sidebarWidth = size.width * sidebarFraction
        let headerHeight = model.density == .compact ? 15.0 : 18.0
        let contentInset = mainInset
        return HStack(spacing: 0) {
            chromeSurface(opacity: model.sidebarOpacity)
                .frame(width: sidebarWidth)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: densitySpacing) {
                        railMark(width: sidebarWidth * 0.50, emphasized: true)
                        railMark(width: sidebarWidth * 0.66)
                        railMark(width: sidebarWidth * 0.56)
                        railMark(width: sidebarWidth * 0.72)
                    }
                    .padding(.horizontal, 7)
                    .padding(.top, headerHeight + 8)
                }

            VStack(spacing: 0) {
                chromeSurface(opacity: model.headerOpacity)
                    .frame(height: headerHeight)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(habitatHex: model.accentHex)).frame(width: 4, height: 4)
                            railMark(width: 32, emphasized: true)
                        }
                        .padding(.leading, 8)
                    }

                VStack(alignment: .leading, spacing: densitySpacing) {
                    contentLine(width: size.width * 0.28, emphasized: true)
                    contentLine(width: size.width * 0.40)
                    contentLine(width: size.width * 0.31)
                    Spacer(minLength: 4)
                    chromeSurface(opacity: model.composerOpacity)
                        .frame(height: model.density == .compact ? 18 : 22)
                        .clipShape(RoundedRectangle(cornerRadius: innerRadius))
                        .overlay(alignment: .leading) {
                            contentLine(width: size.width * 0.24)
                                .padding(.leading, 7)
                        }
                }
                .padding(contentInset)
            }
        }
        .background(homeFrameTreatment)
    }

    @ViewBuilder
    private func chromeSurface(opacity: Double) -> some View {
        switch model.chromeMaterial {
        case .solid:
            Color(habitatHex: model.panelHex).opacity(opacity)
        case .tinted:
            ZStack {
                Color(habitatHex: model.panelHex).opacity(opacity)
                Color(habitatHex: model.accentHex).opacity(0.06)
            }
        case .glass:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(habitatHex: model.panelHex).opacity(opacity * 0.72)
            }
        }
    }

    private func railMark(width: Double, emphasized: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(emphasized
                ? Color(habitatHex: model.accentHex).opacity(0.86)
                : Color(habitatHex: model.textHex).opacity(0.30))
            .frame(width: width, height: emphasized ? 4 : 3)
    }

    private func contentLine(width: Double, emphasized: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(emphasized
                ? Color(habitatHex: model.textHex).opacity(0.72)
                : Color(habitatHex: model.textHex).opacity(0.30))
            .frame(width: width, height: emphasized ? 5 : 3)
    }

    @ViewBuilder
    private var homeFrameTreatment: some View {
        if route == .home, model.homeMode == .quiet {
            Color(habitatHex: model.surfaceHex).opacity(0.10)
        } else if route == .task, model.taskMode == .banner {
            LinearGradient(
                colors: [.clear, Color(habitatHex: model.surfaceHex).opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var artStrength: Double {
        switch route {
        case .home:
            model.homeStrength
        case .task:
            model.taskMode == .off ? 0 : model.taskStrength
        }
    }

    private var sidebarFraction: Double {
        switch model.styleFamily {
        case .retroMessenger, .greenChat: 0.29
        case .classicDesktop: 0.27
        case .arcade, .pixelWorld: 0.22
        default: 0.24
        }
    }

    private var densitySpacing: Double {
        model.density == .compact ? 5 : 7
    }

    private var mainInset: Double {
        route == .home && model.homeMode == .framed ? 8 : 7
    }

    private var outerRadius: Double {
        switch model.styleFamily {
        case .arcade, .classicDesktop, .pixelWorld: 2
        case .retroMessenger, .greenChat: 5
        case .cozyWorld, .fantasyAdventure: 8
        default: 4
        }
    }

    private var innerRadius: Double {
        max(2, outerRadius - 1)
    }

    private var borderWidth: Double {
        switch model.styleFamily {
        case .arcade, .classicDesktop: 1.5
        default: 1
        }
    }

    private var borderColor: Color {
        switch model.styleFamily {
        case .arcade:
            Color(habitatHex: model.accentHex).opacity(0.88)
        case .classicDesktop:
            Color(habitatHex: model.textHex).opacity(0.54)
        default:
            Color(habitatHex: model.accentHex).opacity(0.38)
        }
    }
}

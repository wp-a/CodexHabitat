import Foundation
import HabitatCore
import SwiftUI

enum ThemeTreatmentPreviewRoute: Equatable, Hashable, Sendable {
    case home
    case task
}

enum ThemeTreatmentPreviewSceneMetrics {
    static let bannerArtworkFraction = 0.52
    static let frameMatteThickness = 6.0
    static let homeContentFraction = 0.56
    static let sidebarFraction = 0.24
    static let outerRadius = 6.0
    static let outerBorderWidth = 1.0
    static let railCount = 4
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
    let homeArtworkCrop: HabitatThemeArtworkCrop
    let taskArtworkCrop: HabitatThemeArtworkCrop
    let taskSidebarOpacity: Double
    let taskHeaderOpacity: Double
    let homeContentOpacity: Double
    let taskContentOpacity: Double
    let vignetteStrength: Double
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
        homeArtworkCrop = HabitatThemeArtworkCrop(
            focus: appearance.resolvedHomeArtFocus,
            scale: appearance.resolvedHomeArtScale
        )
        taskArtworkCrop = HabitatThemeArtworkCrop(
            focus: appearance.resolvedTaskArtFocus,
            scale: appearance.resolvedTaskArtScale
        )
        taskSidebarOpacity = appearance.resolvedTaskSidebarOpacity
        taskHeaderOpacity = appearance.resolvedTaskHeaderOpacity
        homeContentOpacity = appearance.resolvedHomeContentOpacity
        taskContentOpacity = appearance.resolvedTaskContentOpacity
        vignetteStrength = appearance.resolvedVignetteStrength
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
            Self.point(homeArtFocus),
            Self.point(taskArtFocus),
            Self.number(homeArtScale),
            Self.number(taskArtScale),
            Self.number(taskSidebarOpacity),
            Self.number(taskHeaderOpacity),
            Self.number(homeContentOpacity),
            Self.number(taskContentOpacity),
            Self.number(vignetteStrength),
        ].joined(separator: "|")
    }

    var chromeSoftness: Double {
        min(max(blurRadius, 0), 24) / 24
    }

    var surfaceRecipe: HabitatThemeSurfaceRecipe {
        styleFamily.surfaceRecipe
    }

    var homeArtFocus: HabitatThemeFocalPoint { homeArtworkCrop.focus }
    var taskArtFocus: HabitatThemeFocalPoint { taskArtworkCrop.focus }
    var homeArtScale: Double { homeArtworkCrop.scale }
    var taskArtScale: Double { taskArtworkCrop.scale }

    private static func point(_ value: HabitatThemeFocalPoint) -> String {
        "\(number(value.x)),\(number(value.y))"
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
    var showsRetryControl = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var image: CGImage?
    @State private var presentationState = ThemePreviewPresentationState()
    @State private var reloadGeneration = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(habitatHex: model.surfaceHex)
                treatmentArtwork(in: geometry.size)
                taskBackgroundTreatment
                chrome(in: geometry.size)
                frameTreatment
            }
            .clipShape(RoundedRectangle(cornerRadius: outerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: outerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .overlay {
            if showsRetryControl, presentationState.showsRetry, imageURL != nil {
                Button(action: retryPreview) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(L10n.text("Retry preview"))
                .accessibilityLabel(L10n.text("Retry preview"))
            }
        }
        .task(id: previewLoadIdentity) {
            let requestID = presentationState.beginRequest()
            let loadedImage = await ThemePreviewStore.shared.image(at: imageURL)
            guard !Task.isCancelled else { return }
            switch presentationState.complete(
                requestID: requestID,
                succeeded: loadedImage != nil
            ) {
            case .displayImage:
                image = loadedImage
            case .clearImage:
                image = nil
            case .ignored:
                break
            }
        }
    }

    private var previewRequestKey: ThemePreviewRequestKey? {
        imageURL.map(ThemePreviewRequestKey.init(url:))
    }

    private var previewLoadIdentity: String {
        let request = previewRequestKey
        return "\(request?.url.path ?? "missing")|\(request?.fileSize ?? -1)|\(request?.modificationDate?.timeIntervalSinceReferenceDate ?? -1)|\(reloadGeneration)"
    }

    private func retryPreview() {
        guard let imageURL else { return }
        Task {
            await ThemePreviewStore.shared.invalidate(url: imageURL)
            reloadGeneration += 1
        }
    }

    @ViewBuilder
    private func treatmentArtwork(in size: CGSize) -> some View {
        if route == .task, model.taskMode == .banner {
            VStack(spacing: 0) {
                artworkLayers(in: size)
                    .frame(
                        height: size.height
                            * ThemeTreatmentPreviewSceneMetrics.bannerArtworkFraction,
                        alignment: .top
                    )
                    .clipped()
                Color(habitatHex: model.surfaceHex)
                    .opacity(0.92)
            }
        } else {
            artworkLayers(in: size)
        }
    }

    private func artworkLayers(in size: CGSize) -> some View {
        ZStack {
            artwork(in: size)
            Color(habitatHex: model.surfaceHex)
                .opacity(1 - artStrength)
            if artStrength > 0 {
                readabilityScrim
                    .opacity(model.vignetteStrength)
            }
        }
    }

    @ViewBuilder
    private func artwork(in size: CGSize) -> some View {
        if artStrength == 0 {
            Color(habitatHex: model.surfaceHex)
        } else if let image {
            let cropRect = artworkCrop.drawRect(
                imageSize: HabitatThemeArtworkCrop.Size(
                    width: Double(image.width),
                    height: Double(image.height)
                ),
                viewportSize: HabitatThemeArtworkCrop.Size(
                    width: size.width,
                    height: size.height
                )
            )
            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .frame(width: cropRect.width, height: cropRect.height)
                    .offset(x: cropRect.x, y: cropRect.y)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
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
                colors: [surface, surface.opacity(0.48), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .trailing:
            LinearGradient(
                colors: [.clear, surface.opacity(0.48), surface],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .center:
            RadialGradient(
                colors: [surface.opacity(0.82), surface.opacity(0.16), .clear],
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
        let headerHeight = (model.density == .compact ? 15.0 : 18.0)
            + recipe.headerEdgeWidth * 0.25
        return HStack(spacing: 0) {
            chromeSurface(opacity: sidebarOpacity)
                .frame(width: sidebarWidth)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color(habitatHex: model.accentHex).opacity(0.52))
                        .frame(width: ThemeTreatmentPreviewSceneMetrics.outerBorderWidth)
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: densitySpacing) {
                        ForEach(0..<ThemeTreatmentPreviewSceneMetrics.railCount, id: \.self) { index in
                            railMark(
                                width: sidebarWidth * railWidth(at: index),
                                emphasized: index == 0
                            )
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.top, headerHeight + 8)
                }

            VStack(spacing: 0) {
                chromeSurface(opacity: headerOpacity)
                    .frame(height: headerHeight)
                    .overlay(alignment: .bottom) {
                        headerTreatment
                    }
                    .overlay(alignment: .leading) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(habitatHex: model.accentHex)).frame(width: 4, height: 4)
                            railMark(width: 32, emphasized: true)
                        }
                        .padding(.leading, 8)
                    }

                contentStage(in: CGSize(
                    width: size.width - sidebarWidth,
                    height: size.height - headerHeight
                ))
            }
        }
    }

    private func contentStage(in size: CGSize) -> some View {
        VStack(spacing: densitySpacing) {
            contentBlock(in: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
            chromeSurface(opacity: model.composerOpacity)
                .frame(height: model.density == .compact ? 18 : 22)
                .clipShape(RoundedRectangle(cornerRadius: recipe.composerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: recipe.composerRadius)
                        .stroke(
                            Color(habitatHex: model.accentHex).opacity(0.46),
                            lineWidth: recipe.composerEdgeWidth
                        )
                }
                .shadow(
                    color: Color(habitatHex: model.surfaceHex).opacity(0.22),
                    radius: recipe.composerShadowRadius
                )
                .overlay(alignment: .leading) {
                    contentLine(width: size.width * 0.32)
                        .padding(.leading, 7)
                }
        }
        .padding(mainInset)
    }

    @ViewBuilder
    private func contentBlock(in size: CGSize) -> some View {
        if route == .home {
            chromeSurface(opacity: model.homeContentOpacity)
                .frame(
                    width: size.width * ThemeTreatmentPreviewSceneMetrics.homeContentFraction,
                    height: size.height * (model.homeMode == .quiet ? 0.56 : 0.46)
                )
                .clipShape(RoundedRectangle(cornerRadius: recipe.readingRadius))
                .overlay {
                    readingSurfaceBorder
                }
                .overlay(alignment: .topLeading) {
                    contentMarks(
                        width: size.width
                            * ThemeTreatmentPreviewSceneMetrics.homeContentFraction
                    )
                }
        } else {
            chromeSurface(opacity: model.taskContentOpacity)
                .clipShape(RoundedRectangle(cornerRadius: recipe.readingRadius))
                .overlay {
                    readingSurfaceBorder
                }
                .overlay(alignment: .topLeading) {
                    contentMarks(width: size.width)
                }
        }
    }

    private func contentMarks(width: Double) -> some View {
        VStack(alignment: .leading, spacing: densitySpacing) {
            contentLine(width: width * 0.52, emphasized: true)
            contentLine(width: width * 0.78)
            if route == .home {
                HStack(spacing: 4) {
                    actionMark(width: width * 0.20, emphasized: true)
                    actionMark(width: width * 0.24, emphasized: false)
                }
            } else {
                contentLine(width: width * 0.64)
            }
        }
        .padding(mainInset)
    }

    @ViewBuilder
    private var frameTreatment: some View {
        if route == .home, model.homeMode == .framed {
            let thickness = ThemeTreatmentPreviewSceneMetrics.frameMatteThickness
            ZStack {
                VStack(spacing: 0) {
                    Color(habitatHex: model.surfaceHex).frame(height: thickness)
                    Spacer(minLength: 0)
                    Color(habitatHex: model.surfaceHex).frame(height: thickness)
                }
                HStack(spacing: 0) {
                    Color(habitatHex: model.surfaceHex).frame(width: thickness)
                    Spacer(minLength: 0)
                    Color(habitatHex: model.surfaceHex).frame(width: thickness)
                }
                RoundedRectangle(cornerRadius: innerRadius)
                    .fill(Color(habitatHex: model.surfaceHex).opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: innerRadius)
                            .stroke(
                                Color(habitatHex: model.accentHex).opacity(0.48),
                                lineWidth: 1
                            )
                    }
                    .padding(thickness)
            }
        }
    }

    @ViewBuilder
    private var taskBackgroundTreatment: some View {
        if route == .task, model.taskMode == .banner {
            LinearGradient(
                colors: [.clear, Color(habitatHex: model.surfaceHex).opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
                Color.white.opacity(model.chromeSoftness * 0.05)
            }
        case .glass:
            if reduceTransparency {
                Color(habitatHex: model.panelHex).opacity(max(opacity, 0.94))
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Color(habitatHex: model.panelHex)
                        .opacity(opacity * (0.82 - model.chromeSoftness * 0.18))
                    Rectangle()
                        .stroke(
                            Color.white.opacity(0.08 + model.chromeSoftness * 0.12),
                            lineWidth: 1
                        )
                }
            }
        }
    }

    private var readingSurfaceBorder: some View {
        RoundedRectangle(cornerRadius: recipe.readingRadius)
            .stroke(
                Color(habitatHex: model.accentHex).opacity(0.34),
                style: strokeStyle(
                    for: recipe.readingLineStyle,
                    width: recipe.readingEdgeWidth
                )
            )
    }

    private var headerTreatment: some View {
        ZStack(alignment: .bottom) {
            Color(habitatHex: model.accentHex)
                .opacity(0.08)
                .frame(height: max(recipe.headerInsetDepth, recipe.headerEdgeWidth))
            Rectangle()
                .stroke(
                    Color(habitatHex: model.accentHex).opacity(0.54),
                    style: strokeStyle(
                        for: recipe.headerLineStyle,
                        width: recipe.headerEdgeWidth
                    )
                )
                .frame(height: max(1, recipe.headerEdgeWidth))
        }
    }

    private func actionMark(width: Double, emphasized: Bool) -> some View {
        RoundedRectangle(cornerRadius: recipe.actionRadius)
            .fill(
                Color(habitatHex: model.panelAltHex).opacity(
                    Double(recipe.hoverEmphasisPercent) / 100 * 0.42
                )
            )
            .frame(width: width, height: 7)
            .overlay {
                RoundedRectangle(cornerRadius: recipe.actionRadius)
                    .stroke(
                        Color(habitatHex: model.accentHex).opacity(0.46),
                        style: strokeStyle(
                            for: recipe.actionLineStyle,
                            width: recipe.actionEdgeWidth
                        )
                    )
            }
            .overlay {
                if emphasized {
                    RoundedRectangle(cornerRadius: recipe.actionRadius)
                        .stroke(
                            Color(habitatHex: model.accentHex).opacity(
                                Double(recipe.focusEmphasisPercent) / 100
                            ),
                            style: focusStrokeStyle(for: recipe.focusStyle)
                        )
                        .padding(-1)
                }
            }
    }

    private func railMark(width: Double, emphasized: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: min(2, recipe.selectedRadius))
            .fill(emphasized
                ? Color(habitatHex: model.accentHex).opacity(0.86)
                : Color(habitatHex: model.textHex).opacity(0.30))
            .frame(width: width, height: emphasized ? 4 : 3)
            .shadow(
                color: Color(habitatHex: model.accentHex).opacity(emphasized ? 0.16 : 0),
                radius: emphasized ? recipe.selectedShadowRadius : 0
            )
            .overlay(alignment: .leading) {
                if emphasized {
                    Rectangle()
                        .fill(Color(habitatHex: model.accentHex))
                        .frame(width: recipe.selectedEdgeWidth, height: 8)
                }
            }
    }

    private func contentLine(width: Double, emphasized: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(emphasized
                ? Color(habitatHex: model.textHex).opacity(0.72)
                : Color(habitatHex: model.textHex).opacity(0.30))
            .frame(width: width, height: emphasized ? 5 : 3)
    }

    private func railWidth(at index: Int) -> Double {
        [0.50, 0.66, 0.56, 0.72, 0.61][index % 5]
    }

    private func strokeStyle(
        for lineStyle: HabitatThemeSurfaceLineStyle,
        width: Double
    ) -> StrokeStyle {
        switch lineStyle {
        case .dashed:
            StrokeStyle(lineWidth: width, dash: [3, 2])
        case .double:
            StrokeStyle(lineWidth: max(2, width), dash: [8, 2])
        case .solid, .raised:
            StrokeStyle(lineWidth: width)
        }
    }

    private func focusStrokeStyle(
        for focusStyle: HabitatThemeSurfaceFocusStyle
    ) -> StrokeStyle {
        switch focusStyle {
        case .standard, .solid:
            StrokeStyle(lineWidth: 1)
        case .dotted:
            StrokeStyle(lineWidth: 1, dash: [1, 2])
        case .double:
            StrokeStyle(lineWidth: 2, dash: [6, 2])
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
        ThemeTreatmentPreviewSceneMetrics.sidebarFraction
    }

    private var artworkCrop: HabitatThemeArtworkCrop {
        route == .home ? model.homeArtworkCrop : model.taskArtworkCrop
    }

    private var sidebarOpacity: Double {
        route == .home ? model.sidebarOpacity : model.taskSidebarOpacity
    }

    private var headerOpacity: Double {
        route == .home ? model.headerOpacity : model.taskHeaderOpacity
    }

    private var contentAlignment: Alignment {
        guard route == .home else { return .center }
        return switch model.safeSide {
        case .leading: .leading
        case .trailing: .trailing
        case .center, .none: .center
        }
    }

    private var densitySpacing: Double {
        model.density == .compact ? 5 : 7
    }

    private var mainInset: Double {
        route == .home && model.homeMode == .framed ? 8 : 7
    }

    private var outerRadius: Double {
        ThemeTreatmentPreviewSceneMetrics.outerRadius
    }

    private var innerRadius: Double {
        max(2, outerRadius - 1)
    }

    private var borderWidth: Double {
        ThemeTreatmentPreviewSceneMetrics.outerBorderWidth
    }

    private var recipe: HabitatThemeSurfaceRecipe {
        model.surfaceRecipe
    }

    private var borderColor: Color {
        switch recipe.materialStyle {
        case .arcadeSignal:
            Color(habitatHex: model.accentHex).opacity(0.88)
        case .desktopRaised:
            Color(habitatHex: model.textHex).opacity(0.54)
        default:
            Color(habitatHex: model.accentHex).opacity(0.38)
        }
    }
}

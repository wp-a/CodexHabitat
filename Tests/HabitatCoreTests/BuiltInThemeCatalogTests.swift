import Foundation
import Testing
@testable import HabitatCore

@Test
func builtInCatalogHasTwentyFourStableThemes() {
    #expect(BuiltInThemeCatalog.all.map(\.id) == [
        "workbench", "night-shift", "arcade-signal", "quiet-garden",
        "retro-messenger", "green-chat-desk", "cyber-cafe", "candy-combo",
        "crimson-mecha", "win95-workbench", "gold-rush", "aqua-pulse",
        "harvest-homestead", "solar-ki-arena", "moonlit-shinobi", "grand-ocean-crew",
        "elemental-companions", "walled-vanguard", "arcane-academy",
        "hero-training-campus", "nebula-vanguard", "spirit-lantern-town",
        "block-frontier", "turbo-striker",
    ])
    #expect(Set(BuiltInThemeCatalog.all.map(\.id)).count == 24)
    #expect(Set(BuiltInThemeCatalog.all.map(\.styleFamily)).count == 9)
    #expect(BuiltInThemeCatalog.all.allSatisfy { !$0.category.localizationKey.isEmpty })
    #expect(Set(HabitatThemeCategory.allCases.map(\.localizationKey)).count ==
        HabitatThemeCategory.allCases.count)
}

@Test
func builtInDisplayNamesAvoidProtectedProductNames() throws {
    #expect(BuiltInThemeCatalog.all.allSatisfy {
        !$0.name.localizedCaseInsensitiveContains("win95")
    })
    #expect(try #require(BuiltInThemeCatalog.definition(id: "win95-workbench")).name ==
        "Classic Desktop Workbench")
}

@Test
func fourPrototypeThemesHaveMateriallyDifferentRouteTreatments() throws {
    let identifiers = ["workbench", "retro-messenger", "arcade-signal", "quiet-garden"]
    let signatures = try identifiers.map { identifier in
        let definition = try #require(BuiltInThemeCatalog.definition(id: identifier))
        return treatmentSignature(definition.appearance(background: "background.jpg"))
    }

    #expect(Set(signatures).count == identifiers.count)
    #expect(BuiltInThemeCatalog.definition(id: "workbench")?.appearance(
        background: "background.jpg"
    ).resolvedHomeMode == .immersive)
    #expect(BuiltInThemeCatalog.definition(id: "retro-messenger")?.appearance(
        background: "background.jpg"
    ).resolvedChromeMaterial == .glass)
    #expect(BuiltInThemeCatalog.definition(id: "arcade-signal")?.appearance(
        background: "background.jpg"
    ).resolvedTaskMode == .banner)
    #expect(BuiltInThemeCatalog.definition(id: "quiet-garden")?.appearance(
        background: "background.jpg"
    ).resolvedTaskMode == .ambient)
    let quietGarden = try #require(BuiltInThemeCatalog.definition(id: "quiet-garden"))
    #expect(quietGarden.palette.surface == "#F4FAF2")
    #expect(quietGarden.palette.panel == "#F9FFF8")
    #expect(quietGarden.palette.panelAlt == "#DCEFD9")
    #expect(quietGarden.palette.text == "#193525")
    #expect(quietGarden.appearance(background: "background.jpg").safeSide == .leading)
    #expect(
        quietGarden.appearance(background: "background.jpg").resolvedLocalizedScrimStrength == 0.70
    )
}

@Test
func lightDesktopThemesProtectCenteredHomeCopyBeyondTheirMinimalVignettes() throws {
    for id in ["green-chat-desk", "win95-workbench"] {
        let definition = try #require(BuiltInThemeCatalog.definition(id: id))
        let appearance = definition.appearance(background: "background.jpg")

        #expect(appearance.resolvedLocalizedScrimStrength == 0.64, "\(id) reading wash")
    }
}

@Test
func builtInTaskScenesAlwaysRetainArtwork() {
    #expect(BuiltInThemeCatalog.all.allSatisfy { definition in
        definition.appearance(background: "background.jpg").resolvedTaskMode != .off
    })
}

@Test
func allBuiltInThemesDeclareExplicitScenes() throws {
    #expect(BuiltInThemeCatalog.all.count == 24)

    for definition in BuiltInThemeCatalog.all {
        let appearance = definition.appearance(background: "background.jpg")
        #expect(definition.treatment != nil, "Missing scene treatment for \(definition.id)")
        #expect(appearance.homeMode != nil, "Missing home mode for \(definition.id)")
        #expect(appearance.taskMode != nil, "Missing task mode for \(definition.id)")
        #expect(appearance.chromeMaterial != nil, "Missing chrome material for \(definition.id)")
        #expect(appearance.homeStrength != nil, "Missing home strength for \(definition.id)")
        #expect(appearance.taskStrength != nil, "Missing task strength for \(definition.id)")
        #expect(appearance.sidebarOpacity != nil, "Missing home sidebar opacity for \(definition.id)")
        #expect(appearance.headerOpacity != nil, "Missing home header opacity for \(definition.id)")
        #expect(appearance.composerOpacity != nil, "Missing composer opacity for \(definition.id)")
        #expect(appearance.homeArtFocus != nil, "Missing home focus for \(definition.id)")
        #expect(appearance.taskArtFocus != nil, "Missing task focus for \(definition.id)")
        #expect(appearance.homeArtScale != nil, "Missing home scale for \(definition.id)")
        #expect(appearance.taskArtScale != nil, "Missing task scale for \(definition.id)")
        #expect(appearance.taskSidebarOpacity != nil, "Missing task sidebar opacity for \(definition.id)")
        #expect(appearance.taskHeaderOpacity != nil, "Missing task header opacity for \(definition.id)")
        #expect(appearance.homeContentOpacity != nil, "Missing home content opacity for \(definition.id)")
        #expect(appearance.taskContentOpacity != nil, "Missing task content opacity for \(definition.id)")
        #expect(appearance.homeContentWidth != nil, "Missing home content width for \(definition.id)")
        #expect(appearance.vignetteStrength != nil, "Missing vignette for \(definition.id)")
        #expect(appearance.artSaturation != nil, "Missing art saturation for \(definition.id)")
        #expect(appearance.artContrast != nil, "Missing art contrast for \(definition.id)")
        #expect(appearance.artExposure != nil, "Missing art exposure for \(definition.id)")
        #expect(
            appearance.localizedScrimStrength != nil,
            "Missing localized scrim strength for \(definition.id)"
        )
        #expect((0.60...1.20).contains(appearance.resolvedArtSaturation))
        #expect((0.80...1.15).contains(appearance.resolvedArtContrast))
        #expect((0.80...1.15).contains(appearance.resolvedArtExposure))
        #expect((0.00...0.70).contains(appearance.resolvedLocalizedScrimStrength))
    }

    for family in HabitatThemeStyleFamily.allCases {
        let familyDefinitions = BuiltInThemeCatalog.all.filter { $0.styleFamily == family }
        #expect(!familyDefinitions.isEmpty, "Missing built-in coverage for \(family.rawValue)")
        #expect(familyDefinitions.contains { definition in
            guard let homeMode = definition.treatment?.homeMode else { return false }
            return homeMode == .immersive || homeMode == .framed
        }, "Missing showcase scene for \(family.rawValue)")
    }
}

@Test
func builtInScenesCoverMateriallyDifferentWholeWindowCompositions() throws {
    let appearances = BuiltInThemeCatalog.all.map {
        $0.appearance(background: "background.jpg")
    }
    let signatures = appearances.map(wholeWindowSignature)
    let signatureCounts = Dictionary(grouping: signatures, by: { $0 }).mapValues(\.count)
    let homeStrengths = appearances.map(\.resolvedHomeStrength)
    let taskStrengths = appearances.map(\.resolvedTaskStrength)
    let safeSides = Set(appearances.map(\.safeSide))

    #expect(Set(signatures).count >= 12)
    #expect((signatureCounts.values.max() ?? 0) <= 6)
    #expect(try #require(homeStrengths.max()) - #require(homeStrengths.min()) >= 0.28)
    #expect(try #require(taskStrengths.max()) - #require(taskStrengths.min()) >= 0.30)
    #expect(safeSides.contains(.leading))
    #expect(safeSides.contains(.trailing))

    let centeredScenes = appearances.filter { $0.safeSide == .center || $0.safeSide == .none }
    #expect(centeredScenes.count <= 4)
    #expect(centeredScenes.allSatisfy {
        $0.resolvedHomeContentOpacity >= 0.60 && $0.resolvedVignetteStrength >= 0.36
    })
}

private func treatmentSignature(_ appearance: HabitatThemeAppearance) -> String {
    [
        appearance.resolvedHomeMode.rawValue,
        appearance.resolvedTaskMode.rawValue,
        appearance.resolvedChromeMaterial.rawValue,
        appearance.density.rawValue,
        String(appearance.resolvedHomeStrength),
        String(appearance.resolvedTaskStrength),
        String(appearance.resolvedSidebarOpacity),
        String(appearance.resolvedHeaderOpacity),
        String(appearance.resolvedComposerOpacity),
    ].joined(separator: "|")
}

private func wholeWindowSignature(_ appearance: HabitatThemeAppearance) -> String {
    [
        appearance.resolvedHomeMode.rawValue,
        appearance.resolvedTaskMode.rawValue,
        appearance.resolvedChromeMaterial.rawValue,
        appearance.density.rawValue,
        appearance.safeSide.rawValue,
        pointSignature(appearance.resolvedHomeArtFocus),
        pointSignature(appearance.resolvedTaskArtFocus),
        numberSignature(appearance.resolvedHomeArtScale),
        numberSignature(appearance.resolvedTaskArtScale),
        numberSignature(appearance.resolvedHomeStrength),
        numberSignature(appearance.resolvedTaskStrength),
        numberSignature(appearance.resolvedSidebarOpacity),
        numberSignature(appearance.resolvedTaskSidebarOpacity),
        numberSignature(appearance.resolvedHeaderOpacity),
        numberSignature(appearance.resolvedTaskHeaderOpacity),
        numberSignature(appearance.resolvedComposerOpacity),
        numberSignature(appearance.resolvedHomeContentOpacity),
        numberSignature(appearance.resolvedTaskContentOpacity),
        numberSignature(appearance.resolvedHomeContentWidth),
        numberSignature(appearance.resolvedVignetteStrength),
        numberSignature(appearance.resolvedArtSaturation),
        numberSignature(appearance.resolvedArtContrast),
        numberSignature(appearance.resolvedArtExposure),
        numberSignature(appearance.resolvedLocalizedScrimStrength),
    ].joined(separator: "|")
}

private func pointSignature(_ point: HabitatThemeFocalPoint) -> String {
    "\(numberSignature(point.x)),\(numberSignature(point.y))"
}

private func numberSignature(_ value: Double) -> String {
    String(format: "%.3f", value)
}

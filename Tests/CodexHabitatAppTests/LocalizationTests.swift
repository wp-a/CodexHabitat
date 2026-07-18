import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test
func simplifiedChineseCatalogCoversPrimaryHabitatSurfaces() {
    let localization = HabitatLocalization(localeIdentifier: "zh-Hans")

    #expect(localization.text("Settings…") == "设置…")
    #expect(localization.text("Show Habitat") == "显示 Habitat")
    #expect(localization.text("Move Habitat") == "移动 Habitat")
    #expect(localization.text("Themes") == "主题")
    #expect(localization.text("Pets") == "宠物")
    #expect(localization.text("Widgets") == "组件")
    #expect(localization.text("Apply Selected Theme to Codex") == "将所选主题应用到 Codex")
    #expect(localization.text("Latest request") == "最近请求")
    #expect(localization.text("Status") == "状态")
    #expect(localization.text("Context") == "上下文")
    #expect(localization.text("Recent 60s output") == "近 60 秒输出")
    #expect(localization.text("Clock") == "时钟")
    #expect(localization.text("Pomodoro") == "番茄钟")
    #expect(localization.text("Context used") == "上下文用量")
    #expect(localization.text("Task cumulative") == "任务累计")
    #expect(localization.format("%d diagnostic events", 3) == "3 条诊断事件")
    #expect(localization.format("%d pets, %d packs valid", 2, 4) == "2 个宠物、4 个资源包有效")
    #expect(localization.text("LIVE") == "实时")

    for definition in BuiltInThemeCatalog.all {
        #expect(localization.text(definition.name) != definition.name)
        #expect(localization.text(definition.detail) != definition.detail)
    }
    for key in [
        "All", "Nostalgia", "Chat", "Anime", "Games", "Cozy", "Classic", "Custom",
        "Search themes", "Create Theme", "Theme Studio", "Save Locally",
        "Home treatment", "Task treatment", "Chrome material",
        "Immersive", "Framed", "Quiet", "Ambient", "Banner", "Off",
        "Solid", "Tinted", "Glass", "Center", "Home strength", "Task strength",
        "Sidebar opacity", "Header opacity", "Composer opacity",
        "Edit theme", "Replace existing theme?", "Replace Theme",
        "Replacement confirmation required",
        "A local theme with this name already exists. Replace it with this draft?",
        "Choose a local background image.",
        "Export does not grant image rights. You confirm you may use and share this image.",
        "Theme names must be 100 characters or fewer and contain no control characters.",
        "Authors must be 100 characters or fewer and contain no control characters.",
    ] {
        #expect(localization.text(key) != key)
    }
    #expect(localization.format("Edit %@", "测试主题") == "编辑测试主题")
    for category in HabitatThemeCategory.allCases {
        #expect(localization.text(category.localizationKey) != category.localizationKey)
    }
}

@Test
func themeStudioSliderTitlesUseDynamicLocalization() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = repositoryRoot
        .appendingPathComponent("Sources/CodexHabitatApp/Settings/ThemeStudioView.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let sliderStart = try #require(source.range(of: "private func valueSlider("))
    let sliderEnd = try #require(source.range(
        of: "private func colorBinding",
        range: sliderStart.upperBound..<source.endIndex
    ))
    let sliderImplementation = source[sliderStart.lowerBound..<sliderEnd.lowerBound]

    #expect(sliderImplementation.contains("Text(L10n.text(title))"))
}

@Test
func unsupportedLocalesFallBackToEnglishCatalog() {
    let localization = HabitatLocalization(localeIdentifier: "fr-FR")

    #expect(localization.resolvedLanguage == "en")
    #expect(localization.text("Settings…") == "Settings…")
    #expect(localization.text("Theme session active") == "Theme session active")
}

@Test
func localizationCatalogsHaveMatchingKeysAndFormatPlaceholders() throws {
    let english = try HabitatLocalization.catalog(language: "en")
    let chinese = try HabitatLocalization.catalog(language: "zh-Hans")

    #expect(Set(english.keys) == Set(chinese.keys))
    #expect(english.count >= 100)
    for key in english.keys {
        #expect(
            HabitatLocalization.formatPlaceholders(in: english[key] ?? "")
                == HabitatLocalization.formatPlaceholders(in: chinese[key] ?? "")
        )
    }
}

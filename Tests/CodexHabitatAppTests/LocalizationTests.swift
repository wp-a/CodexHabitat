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
    #expect(localization.text("Tokens") == "Token 用量")
    #expect(localization.text("Status") == "状态")
    #expect(localization.text("Context") == "上下文")
    #expect(localization.text("Speed") == "速度")
    #expect(localization.text("Clock") == "时钟")
    #expect(localization.text("Pomodoro") == "番茄钟")
    #expect(localization.text("Context used") == "上下文用量")
    #expect(localization.text("Output speed") == "输出速度")
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

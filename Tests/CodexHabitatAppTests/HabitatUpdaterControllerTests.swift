import Foundation
import Testing
@testable import CodexHabitatApp

@Test
func updateConfigurationRequiresExplicitHTTPSAndAnEdDSAPublicKey() throws {
    let key = Data(repeating: 7, count: 32).base64EncodedString()
    let valid = try #require(HabitatUpdateConfiguration(infoDictionary: [
        "HabitatUpdatesEnabled": true,
        "SURequireSignedFeed": true,
        "SUVerifyUpdateBeforeExtraction": true,
        "SUFeedURL": "https://updates.codexhabitat.example/appcast.xml",
        "SUPublicEDKey": key,
    ]))

    #expect(valid.feedURL.absoluteString == "https://updates.codexhabitat.example/appcast.xml")
    #expect(valid.publicEDKey == key)
    #expect(HabitatUpdateConfiguration(infoDictionary: [
        "HabitatUpdatesEnabled": false,
        "SURequireSignedFeed": true,
        "SUVerifyUpdateBeforeExtraction": true,
        "SUFeedURL": "https://updates.codexhabitat.example/appcast.xml",
        "SUPublicEDKey": key,
    ]) == nil)
    #expect(HabitatUpdateConfiguration(infoDictionary: [
        "HabitatUpdatesEnabled": true,
        "SURequireSignedFeed": true,
        "SUVerifyUpdateBeforeExtraction": true,
        "SUFeedURL": "http://updates.codexhabitat.example/appcast.xml",
        "SUPublicEDKey": key,
    ]) == nil)
    #expect(HabitatUpdateConfiguration(infoDictionary: [
        "HabitatUpdatesEnabled": true,
        "SURequireSignedFeed": true,
        "SUVerifyUpdateBeforeExtraction": true,
        "SUFeedURL": "https://updates.codexhabitat.example/appcast.xml?token=secret",
        "SUPublicEDKey": key,
    ]) == nil)
    #expect(HabitatUpdateConfiguration(infoDictionary: [
        "HabitatUpdatesEnabled": true,
        "SURequireSignedFeed": true,
        "SUVerifyUpdateBeforeExtraction": true,
        "SUFeedURL": "https://updates.codexhabitat.example/appcast.xml",
        "SUPublicEDKey": Data(repeating: 7, count: 31).base64EncodedString(),
    ]) == nil)
    #expect(HabitatUpdateConfiguration(infoDictionary: [
        "HabitatUpdatesEnabled": true,
        "SURequireSignedFeed": false,
        "SUVerifyUpdateBeforeExtraction": true,
        "SUFeedURL": "https://updates.codexhabitat.example/appcast.xml",
        "SUPublicEDKey": key,
    ]) == nil)
}

@MainActor
@Test
func updaterIsAlwaysDisabledInDebugBuilds() {
    #if DEBUG
    #expect(!HabitatUpdaterController().isAvailable)
    #endif
}

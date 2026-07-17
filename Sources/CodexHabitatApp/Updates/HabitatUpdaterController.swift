import Foundation
import Sparkle

struct HabitatUpdateConfiguration: Equatable, Sendable {
    let feedURL: URL
    let publicEDKey: String

    init?(infoDictionary: [String: Any]) {
        guard infoDictionary["HabitatUpdatesEnabled"] as? Bool == true,
              infoDictionary["SURequireSignedFeed"] as? Bool == true,
              infoDictionary["SUVerifyUpdateBeforeExtraction"] as? Bool == true,
              let rawFeedURL = infoDictionary["SUFeedURL"] as? String,
              let feedURL = URL(string: rawFeedURL),
              feedURL.scheme?.lowercased() == "https",
              feedURL.host != nil,
              feedURL.user == nil,
              feedURL.password == nil,
              feedURL.query == nil,
              feedURL.fragment == nil,
              let publicEDKey = infoDictionary["SUPublicEDKey"] as? String,
              Data(base64Encoded: publicEDKey)?.count == 32
        else {
            return nil
        }
        self.feedURL = feedURL
        self.publicEDKey = publicEDKey
    }
}

@MainActor
final class HabitatUpdaterController {
    private let controller: SPUStandardUpdaterController?

    var isAvailable: Bool { controller != nil }

    init(bundle: Bundle = .main) {
        #if DEBUG
        controller = nil
        #else
        guard HabitatUpdateConfiguration(
            infoDictionary: bundle.infoDictionary ?? [:]
        ) != nil else {
            controller = nil
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

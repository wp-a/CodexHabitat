import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test(arguments: [
    (ConnectionHealth.online, "Connected", "LIVE", "network"),
    (ConnectionHealth.estimated, "Local activity estimate", "EST.", "waveform.path.ecg"),
    (ConnectionHealth.reconnecting, "Reconnecting", "RETRY", "arrow.trianglehead.2.clockwise.rotate.90"),
    (ConnectionHealth.offline, "Disconnected", "OFF", "network.slash"),
])
func menuConnectionPresentationIsExplicit(
    health: ConnectionHealth,
    title: String,
    badge: String,
    symbol: String
) {
    let presentation = HabitatMenuConnectionPresentation(health: health)

    #expect(presentation.title == title)
    #expect(presentation.badge == badge)
    #expect(presentation.symbol == symbol)
}

@Test
func moveModeMenuPresentationMakesTheTemporaryStateExplicit() {
    #expect(HabitatMoveModePresentation(isActive: false).title == "Move Habitat")
    #expect(HabitatMoveModePresentation(isActive: false).symbol == "arrow.up.and.down.and.arrow.left.and.right")
    #expect(HabitatMoveModePresentation(isActive: true).title == "Finish Moving")
    #expect(HabitatMoveModePresentation(isActive: true).symbol == "checkmark")
}

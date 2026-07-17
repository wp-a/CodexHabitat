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

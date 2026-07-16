import Testing
@testable import HabitatCore

@Test
func packageExposesVersion() {
    #expect(HabitatCore.version == "0.1.0-dev")
}

import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func presenterEmitsStableCodeForEachApplyStage() {
    #expect(
        ThemeBridgeErrorPresenter.line(for: ThemeBridgeCoordinatorError.listenerNotOwned)
            == "theme-bridge: code=listenerUnavailable"
    )
    #expect(
        ThemeBridgeErrorPresenter.line(for: ThemeBridgeCoordinatorError.targetUnavailable)
            == "theme-bridge: code=targetUnavailable"
    )
    #expect(
        ThemeBridgeErrorPresenter.line(for: ThemeBridgeCoordinatorError.runtimeUnavailable)
            == "theme-bridge: code=runtimeUnavailable"
    )
    #expect(
        ThemeBridgeErrorPresenter.line(for: ThemeBridgeCoordinatorError.healthCheckFailed)
            == "theme-bridge: code=domHealthRejected"
    )
}

@Test
func presenterMapsTargetValidationToProcessRejected() {
    #expect(
        ThemeBridgeErrorPresenter.line(for: CDPTargetValidationError.nonLoopbackURL)
            == "theme-bridge: code=processRejected"
    )
}

@Test
func presenterRedactsUnderlyingTransportDescriptions() {
    let line = ThemeBridgeErrorPresenter.line(for: SensitivePresenterError())

    #expect(line == "theme-bridge: code=unknown")
    #expect(!line.contains("wss://"))
    #expect(!line.contains("secret"))
}

private struct SensitivePresenterError: Error, CustomStringConvertible {
    var description: String { "wss://secret.example.invalid/private" }
}

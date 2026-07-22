import Testing
@testable import CodexHabitatApp

@Test
func startingAReplacementRequestRetainsThePreviousImage() {
    var state = ThemePreviewPresentationState()
    let first = state.beginRequest()
    #expect(state.complete(requestID: first, succeeded: true) == .displayImage)

    _ = state.beginRequest()

    #expect(state.phase == .loading)
    #expect(state.hasPresentedImage)
    #expect(!state.showsPlaceholder)
}

@Test
func successfulReplacementAuthorizesTheNewImage() {
    var state = ThemePreviewPresentationState()
    let request = state.beginRequest()

    let completion = state.complete(requestID: request, succeeded: true)

    #expect(completion == .displayImage)
    #expect(state.phase == .loaded)
    #expect(state.hasPresentedImage)
    #expect(!state.showsRetry)
}

@Test
func failedReplacementClearsTheOldImageAndExposesRetry() {
    var state = ThemePreviewPresentationState()
    let first = state.beginRequest()
    _ = state.complete(requestID: first, succeeded: true)
    let replacement = state.beginRequest()

    let completion = state.complete(requestID: replacement, succeeded: false)

    #expect(completion == .clearImage)
    #expect(state.phase == .failed)
    #expect(!state.hasPresentedImage)
    #expect(state.showsPlaceholder)
    #expect(state.showsRetry)
}

@Test
func staleOrCancelledRequestCannotOverrideTheCurrentRequest() {
    var state = ThemePreviewPresentationState()
    let stale = state.beginRequest()
    let current = state.beginRequest()

    #expect(state.complete(requestID: stale, succeeded: true) == .ignored)
    #expect(state.phase == .loading)
    #expect(!state.hasPresentedImage)
    #expect(state.complete(requestID: current, succeeded: false) == .clearImage)
    #expect(state.phase == .failed)
}

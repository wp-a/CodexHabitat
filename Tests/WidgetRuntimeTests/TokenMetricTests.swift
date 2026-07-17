import Foundation
import HabitatCore
import Testing
@testable import WidgetRuntime

@Test
func tokenContextAndSpeedMetricsStayTypedAndBounded() {
    let snapshot = HabitatSnapshot(tokenMetrics: TokenMetricsSummary(
        inputTokens: 1_000,
        cachedInputTokens: 600,
        outputTokens: 100,
        reasoningOutputTokens: 20,
        totalTokens: 1_100,
        lastInputTokens: 500,
        lastOutputTokens: 40,
        modelContextWindow: 1_000,
        outputTokensPerMinute: 120,
        updatedAt: Date(timeIntervalSince1970: 200)
    ))

    #expect(TokenWidget.metric(snapshot: snapshot) == .tokenCount(1_100))
    #expect(ContextWidget.metric(snapshot: snapshot) == .percentage(50))
    #expect(SpeedWidget.metric(snapshot: snapshot) == .tokensPerMinute(120))
}

@Test
func contextMetricClampsUnexpectedValues() {
    let snapshot = HabitatSnapshot(tokenMetrics: TokenMetricsSummary(
        inputTokens: 2_000,
        cachedInputTokens: 0,
        outputTokens: 0,
        reasoningOutputTokens: 0,
        totalTokens: 2_000,
        lastInputTokens: 2_000,
        lastOutputTokens: 0,
        modelContextWindow: 1_000,
        outputTokensPerMinute: nil,
        updatedAt: Date(timeIntervalSince1970: 200)
    ))

    #expect(ContextWidget.metric(snapshot: snapshot) == .percentage(100))
    #expect(SpeedWidget.metric(snapshot: snapshot) == .unavailable)
}

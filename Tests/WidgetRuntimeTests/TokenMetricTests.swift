import Foundation
import HabitatCore
import Testing
@testable import WidgetRuntime

@Test
func latestRequestContextAndRecentOutputMetricsStayTypedAndBounded() {
    let snapshot = HabitatSnapshot(tokenMetrics: TokenMetricsSummary(
        inputTokens: 1_000,
        cachedInputTokens: 600,
        outputTokens: 100,
        reasoningOutputTokens: 20,
        totalTokens: 1_100,
        lastInputTokens: 500,
        lastOutputTokens: 40,
        modelContextWindow: 1_000,
        recentOutputTokens: 40,
        updatedAt: Date(timeIntervalSince1970: 200)
    ))

    #expect(TokenWidget.metric(snapshot: snapshot) == .tokenCount(540))
    #expect(ContextWidget.metric(snapshot: snapshot) == .percentage(50))
    #expect(SpeedWidget.metric(snapshot: snapshot) == .recentTokenCount(40, windowSeconds: 60))
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
        recentOutputTokens: nil,
        updatedAt: Date(timeIntervalSince1970: 200)
    ))

    #expect(ContextWidget.metric(snapshot: snapshot) == .percentage(100))
    #expect(SpeedWidget.metric(snapshot: snapshot) == .unavailable)
}

@Test
func lastRequestMetricsRemainUnavailableWhenTheEventOmitsThem() {
    let snapshot = HabitatSnapshot(tokenMetrics: TokenMetricsSummary(
        inputTokens: 2_000,
        cachedInputTokens: 0,
        outputTokens: 100,
        reasoningOutputTokens: 0,
        totalTokens: 2_100,
        lastInputTokens: nil,
        lastOutputTokens: nil,
        modelContextWindow: 4_000,
        recentOutputTokens: nil,
        updatedAt: Date(timeIntervalSince1970: 200)
    ))

    #expect(TokenWidget.metric(snapshot: snapshot) == .unavailable)
    #expect(ContextWidget.metric(snapshot: snapshot) == .unavailable)
}

@Test
func latestRequestMetricRefusesIntegerOverflow() {
    let snapshot = HabitatSnapshot(tokenMetrics: TokenMetricsSummary(
        inputTokens: Int.max,
        cachedInputTokens: 0,
        outputTokens: 1,
        reasoningOutputTokens: 0,
        totalTokens: Int.max,
        lastInputTokens: Int.max,
        lastOutputTokens: 1,
        modelContextWindow: Int.max,
        recentOutputTokens: nil,
        updatedAt: Date(timeIntervalSince1970: 200)
    ))

    #expect(snapshot.tokenMetrics?.latestRequestTokens == nil)
    #expect(TokenWidget.metric(snapshot: snapshot) == .unavailable)
}

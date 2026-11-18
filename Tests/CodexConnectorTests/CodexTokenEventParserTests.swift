import Foundation
import HabitatCore
import Testing
@testable import CodexConnector

@Test
func tokenParserAcceptsOnlyTokenCountEvents() throws {
    let fixture = try #require(Bundle.module.url(
        forResource: "token-events-mixed",
        withExtension: "jsonl",
        subdirectory: "Fixtures"
    ))
    let lines = try String(contentsOf: fixture, encoding: .utf8)
        .split(separator: "\n")
        .map { Data($0.utf8) }
    let parser = CodexTokenEventParser()

    #expect(parser.parse(lines[0]) == nil)
    #expect(parser.parse(lines[1]) == nil)
    let event = try #require(parser.parse(lines[2]))
    #expect(event.timestamp == Date(timeIntervalSince1970: 1_784_260_802))
    #expect(event.metrics.inputTokens == 1_000)
    #expect(event.metrics.cachedInputTokens == 600)
    #expect(event.metrics.outputTokens == 100)
    #expect(event.metrics.reasoningOutputTokens == 20)
    #expect(event.metrics.totalTokens == 1_100)
    #expect(event.metrics.lastInputTokens == 500)
    #expect(event.metrics.lastOutputTokens == 40)
    #expect(event.metrics.modelContextWindow == 1_000)
    #expect(event.metrics.latestRequestTokens == 540)
    #expect(event.metrics.taskCumulativeTokens == 1_100)
    #expect(event.metrics.contextUsedPercent == 50)
    #expect(event.metrics.recentOutputTokens == nil)
}

@Test
func tokenParserKeepsMissingLastRequestMetricsUnavailable() throws {
    let line = Data(#"{"timestamp":"2026-07-17T04:00:02.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":600,"output_tokens":100,"reasoning_output_tokens":20,"total_tokens":1100},"model_context_window":1000}}}"#.utf8)
    let metrics = try #require(CodexTokenEventParser().parse(line)?.metrics)

    #expect(metrics.lastInputTokens == nil)
    #expect(metrics.lastOutputTokens == nil)
    #expect(metrics.latestRequestTokens == nil)
    #expect(metrics.contextUsedPercent == nil)
}

@Test
func tokenParserRejectsMalformedAndTruncatedRecords() {
    let parser = CodexTokenEventParser()

    #expect(parser.parse(Data()) == nil)
    #expect(parser.parse(Data("{".utf8)) == nil)
    #expect(parser.parse(Data(#"{"type":"event_msg","payload":{"type":"token_count"}}"#.utf8)) == nil)
}

@Test
func tokenParserExtractsSessionRateLimitsAndSupportsTokenUsageRecords() throws {
    let parser = CodexTokenEventParser()

    let withRateLimits = Data(#"{"timestamp":"2026-11-18T05:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":2400,"cached_input_tokens":1200,"output_tokens":320,"reasoning_output_tokens":64,"total_tokens":2720},"last_token_usage":{"input_tokens":800,"cached_input_tokens":400,"output_tokens":120,"reasoning_output_tokens":16,"total_tokens":920},"model_context_window":200000},"rate_limits":{"primary":{"used_percent":42.5,"resets_at":"2026-11-18T09:00:00Z"},"secondary":{"used_percent":18.0,"resets_at":1795000000}}}}"#.utf8)
    let event = try #require(parser.parse(withRateLimits))
    #expect(event.metrics.latestRequestTokens == 920)
    #expect(event.rateLimits?.primaryUsedPercent == 42.5)
    #expect(event.rateLimits?.secondaryUsedPercent == 18.0)
    #expect(event.rateLimits?.primaryResetAt != nil)
    #expect(event.rateLimits?.secondaryResetAt == Date(timeIntervalSince1970: 1_795_000_000))

    let usageRecord = Data(#"{"timestamp":"2026-11-18T05:01:00.000Z","type":"token_usage_record","payload":{"thread_id":"secret-thread","usage":{"input_tokens":900,"cached_input_tokens":500,"output_tokens":150,"reasoning_output_tokens":30,"total_tokens":1050},"thread_token_usage":{"input_tokens":3300,"cached_input_tokens":1700,"output_tokens":470,"reasoning_output_tokens":94,"total_tokens":3770}}}"#.utf8)
    let recordEvent = try #require(parser.parse(usageRecord))
    #expect(recordEvent.metrics.totalTokens == 3_770)
    #expect(recordEvent.metrics.lastInputTokens == 900)
    #expect(recordEvent.metrics.lastOutputTokens == 150)
    #expect(recordEvent.metrics.latestRequestTokens == 1_050)
}

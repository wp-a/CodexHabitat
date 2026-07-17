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

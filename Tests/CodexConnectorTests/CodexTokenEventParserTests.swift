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
    #expect(event.metrics.contextUsedPercent == 50)
    #expect(event.metrics.outputTokensPerMinute == nil)
}

@Test
func tokenParserRejectsMalformedAndTruncatedRecords() {
    let parser = CodexTokenEventParser()

    #expect(parser.parse(Data()) == nil)
    #expect(parser.parse(Data("{".utf8)) == nil)
    #expect(parser.parse(Data(#"{"type":"event_msg","payload":{"type":"token_count"}}"#.utf8)) == nil)
}

import Foundation
import HabitatCore

public struct CodexTokenEvent: Equatable, Sendable {
    public let timestamp: Date
    public let metrics: TokenMetricsSummary
}

public struct CodexTokenEventParser: Sendable {
    public init() {}

    public func parse(_ data: Data) -> CodexTokenEvent? {
        guard !data.isEmpty,
              data.count <= 512 * 1024,
              let header = try? JSONDecoder().decode(EventHeader.self, from: data),
              header.type == "event_msg",
              header.payload.type == "token_count",
              let event = try? JSONDecoder().decode(TokenEnvelope.self, from: data),
              let timestamp = Self.parseTimestamp(event.timestamp)
        else {
            return nil
        }

        let total = event.payload.info.totalTokenUsage
        let last = event.payload.info.lastTokenUsage
        let totalValues = [
            total.inputTokens,
            total.cachedInputTokens,
            total.outputTokens,
            total.reasoningOutputTokens,
            total.totalTokens,
        ]
        let lastValues = last.map {
            [
                $0.inputTokens,
                $0.cachedInputTokens,
                $0.outputTokens,
                $0.reasoningOutputTokens,
                $0.totalTokens,
            ]
        } ?? []
        guard (totalValues + lastValues).allSatisfy({ $0 >= 0 }),
              event.payload.info.modelContextWindow.map({ $0 > 0 }) ?? true
        else {
            return nil
        }

        return CodexTokenEvent(
            timestamp: timestamp,
            metrics: TokenMetricsSummary(
                inputTokens: total.inputTokens,
                cachedInputTokens: total.cachedInputTokens,
                outputTokens: total.outputTokens,
                reasoningOutputTokens: total.reasoningOutputTokens,
                totalTokens: total.totalTokens,
                lastInputTokens: last?.inputTokens,
                lastOutputTokens: last?.outputTokens,
                modelContextWindow: event.payload.info.modelContextWindow,
                recentOutputTokens: nil,
                updatedAt: timestamp
            )
        )
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private struct EventHeader: Decodable {
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String
    }
}

private struct TokenEnvelope: Decodable {
    let timestamp: String
    let payload: Payload

    struct Payload: Decodable {
        let info: Info
    }

    struct Info: Decodable {
        let totalTokenUsage: Usage
        let lastTokenUsage: Usage?
        let modelContextWindow: Int?

        enum CodingKeys: String, CodingKey {
            case totalTokenUsage = "total_token_usage"
            case lastTokenUsage = "last_token_usage"
            case modelContextWindow = "model_context_window"
        }
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let cachedInputTokens: Int
        let outputTokens: Int
        let reasoningOutputTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case cachedInputTokens = "cached_input_tokens"
            case outputTokens = "output_tokens"
            case reasoningOutputTokens = "reasoning_output_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

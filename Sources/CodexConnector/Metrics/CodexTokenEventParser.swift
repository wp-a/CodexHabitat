import Foundation
import HabitatCore

public struct CodexTokenEvent: Equatable, Sendable {
    public let timestamp: Date
    public let metrics: TokenMetricsSummary
    public let rateLimits: CodexRateLimitUpdate?

    public init(
        timestamp: Date,
        metrics: TokenMetricsSummary,
        rateLimits: CodexRateLimitUpdate? = nil
    ) {
        self.timestamp = timestamp
        self.metrics = metrics
        self.rateLimits = rateLimits
    }
}

public struct CodexTokenEventParser: Sendable {
    public init() {}

    public func parse(_ data: Data) -> CodexTokenEvent? {
        guard !data.isEmpty,
              data.count <= 512 * 1024,
              let kind = try? JSONDecoder().decode(TopLevelTypeHeader.self, from: data)
        else {
            return nil
        }

        switch kind.type {
        case "event_msg":
            return parseEventMessage(data)
        case "token_usage_record":
            return parseTokenUsageRecord(data)
        default:
            return nil
        }
    }

    private func parseEventMessage(_ data: Data) -> CodexTokenEvent? {
        guard let header = try? JSONDecoder().decode(EventHeader.self, from: data),
              header.payload.type == "token_count",
              let event = try? JSONDecoder().decode(TokenEnvelope.self, from: data),
              let timestamp = Self.parseTimestamp(event.timestamp)
        else {
            return nil
        }

        let total = event.payload.info.totalTokenUsage
        let last = event.payload.info.lastTokenUsage
        guard Self.isValidUsage(total, last: last, contextWindow: event.payload.info.modelContextWindow)
        else {
            return nil
        }

        return CodexTokenEvent(
            timestamp: timestamp,
            metrics: Self.makeSummary(
                total: total,
                last: last,
                modelContextWindow: event.payload.info.modelContextWindow,
                timestamp: timestamp
            ),
            rateLimits: Self.parseRateLimits(event.payload.rateLimits)
        )
    }

    private func parseTokenUsageRecord(_ data: Data) -> CodexTokenEvent? {
        guard let record = try? JSONDecoder().decode(TokenUsageRecordEnvelope.self, from: data),
              let timestamp = Self.parseTimestamp(record.timestamp),
              let total = record.payload.threadTokenUsage ?? record.payload.turnTokenUsage ?? record.payload.usage
        else {
            return nil
        }
        let last = record.payload.usage ?? record.payload.turnTokenUsage
        guard Self.isValidUsage(total, last: last, contextWindow: nil) else {
            return nil
        }
        return CodexTokenEvent(
            timestamp: timestamp,
            metrics: Self.makeSummary(
                total: total,
                last: last,
                modelContextWindow: nil,
                timestamp: timestamp
            ),
            rateLimits: nil
        )
    }

    private static func isValidUsage(
        _ total: Usage,
        last: Usage?,
        contextWindow: Int?
    ) -> Bool {
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
        return (totalValues + lastValues).allSatisfy { $0 >= 0 }
            && (contextWindow.map { $0 > 0 } ?? true)
    }

    private static func makeSummary(
        total: Usage,
        last: Usage?,
        modelContextWindow: Int?,
        timestamp: Date
    ) -> TokenMetricsSummary {
        TokenMetricsSummary(
            inputTokens: total.inputTokens,
            cachedInputTokens: total.cachedInputTokens,
            outputTokens: total.outputTokens,
            reasoningOutputTokens: total.reasoningOutputTokens,
            totalTokens: total.totalTokens,
            lastInputTokens: last?.inputTokens,
            lastOutputTokens: last?.outputTokens,
            modelContextWindow: modelContextWindow,
            recentOutputTokens: nil,
            updatedAt: timestamp
        )
    }

    private static func parseRateLimits(_ raw: RawRateLimits?) -> CodexRateLimitUpdate? {
        guard let raw else { return nil }
        let primaryUsed = raw.primary?.usedPercent
        let primaryReset = raw.primary?.resetDate
        let secondaryUsed = raw.secondary?.usedPercent
        let secondaryReset = raw.secondary?.resetDate
        guard primaryUsed != nil || primaryReset != nil || secondaryUsed != nil || secondaryReset != nil
        else {
            return nil
        }
        return CodexRateLimitUpdate(
            primaryUsedPercent: primaryUsed,
            primaryResetAt: primaryReset,
            secondaryUsedPercent: secondaryUsed,
            secondaryResetAt: secondaryReset
        )
    }

    static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private struct TopLevelTypeHeader: Decodable {
    let type: String
}

private struct EventHeader: Decodable {
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String
    }
}

private struct Usage: Decodable {
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

private struct RawRateLimits: Decodable {
    let primary: Bucket?
    let secondary: Bucket?

    struct Bucket: Decodable {
        let usedPercent: Double?
        let resetDate: Date?

        private enum CodingKeys: String, CodingKey {
            case usedPercentSnake = "used_percent"
            case usedPercentCamel = "usedPercent"
            case resetsAtSnake = "resets_at"
            case resetAtSnake = "reset_at"
            case resetsAtCamel = "resetsAt"
            case resetAtCamel = "resetAt"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            usedPercent = (try? container.decodeIfPresent(Double.self, forKey: .usedPercentSnake))
                ?? (try? container.decodeIfPresent(Double.self, forKey: .usedPercentCamel))
            resetDate = Self.decodeDate(from: container, keys: [
                .resetsAtSnake, .resetAtSnake, .resetsAtCamel, .resetAtCamel,
            ])
        }

        private static func decodeDate(
            from container: KeyedDecodingContainer<CodingKeys>,
            keys: [CodingKeys]
        ) -> Date? {
            for key in keys {
                if let epoch = try? container.decodeIfPresent(Double.self, forKey: key),
                   epoch > 0, epoch.isFinite {
                    return Date(timeIntervalSince1970: epoch)
                }
                if let text = try? container.decodeIfPresent(String.self, forKey: key),
                   let parsed = CodexTokenEventParser.parseTimestamp(text) {
                    return parsed
                }
            }
            return nil
        }
    }
}

private struct TokenEnvelope: Decodable {
    let timestamp: String
    let payload: Payload

    struct Payload: Decodable {
        let info: Info
        let rateLimits: RawRateLimits?

        enum CodingKeys: String, CodingKey {
            case info
            case rateLimits = "rate_limits"
        }
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
}

private struct TokenUsageRecordEnvelope: Decodable {
    let timestamp: String
    let payload: Payload

    struct Payload: Decodable {
        let usage: Usage?
        let turnTokenUsage: Usage?
        let threadTokenUsage: Usage?

        enum CodingKeys: String, CodingKey {
            case usage
            case turnTokenUsage = "turn_token_usage"
            case threadTokenUsage = "thread_token_usage"
        }
    }
}

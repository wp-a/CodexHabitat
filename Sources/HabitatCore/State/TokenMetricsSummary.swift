import Foundation

public struct TokenMetricsSummary: Codable, Equatable, Sendable {
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let reasoningOutputTokens: Int
    public let totalTokens: Int
    public let lastInputTokens: Int?
    public let lastOutputTokens: Int?
    public let modelContextWindow: Int?
    public let recentOutputTokens: Int?
    public let updatedAt: Date

    public init(
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        reasoningOutputTokens: Int,
        totalTokens: Int,
        lastInputTokens: Int?,
        lastOutputTokens: Int?,
        modelContextWindow: Int?,
        recentOutputTokens: Int?,
        updatedAt: Date
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        self.totalTokens = totalTokens
        self.lastInputTokens = lastInputTokens
        self.lastOutputTokens = lastOutputTokens
        self.modelContextWindow = modelContextWindow
        self.recentOutputTokens = recentOutputTokens
        self.updatedAt = updatedAt
    }

    public var latestRequestTokens: Int? {
        guard let lastInputTokens, let lastOutputTokens else { return nil }
        let (value, overflow) = lastInputTokens.addingReportingOverflow(lastOutputTokens)
        return overflow ? nil : value
    }

    public var taskCumulativeTokens: Int {
        totalTokens
    }

    public var contextUsedPercent: Double? {
        guard let lastInputTokens, let modelContextWindow, modelContextWindow > 0 else {
            return nil
        }
        return min(max(Double(lastInputTokens) / Double(modelContextWindow) * 100, 0), 100)
    }

    public func withRecentOutputTokens(_ value: Int?) -> TokenMetricsSummary {
        TokenMetricsSummary(
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            outputTokens: outputTokens,
            reasoningOutputTokens: reasoningOutputTokens,
            totalTokens: totalTokens,
            lastInputTokens: lastInputTokens,
            lastOutputTokens: lastOutputTokens,
            modelContextWindow: modelContextWindow,
            recentOutputTokens: value,
            updatedAt: updatedAt
        )
    }
}

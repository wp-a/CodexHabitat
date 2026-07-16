import Foundation
import HabitatCore
import Testing
@testable import WidgetRuntime

@Test
func registryContainsExactlyTheFiveBuiltInWidgetIDs() {
    let registry = WidgetRegistry.builtIn

    #expect(registry.descriptors.count == 5)
    #expect(Set(registry.descriptors.map(\.id)) == Set(WidgetIdentifier.allCases))
}

@Test
func registryRejectsConfigurationForAnotherWidgetType() {
    let registry = WidgetRegistry.builtIn

    #expect(throws: WidgetConfigurationError.configurationTypeMismatch) {
        try registry.validate(
            configuration: .clock(ClockWidgetConfiguration()),
            for: .status
        )
    }
    #expect(throws: Never.self) {
        try registry.validate(
            configuration: .usage(UsageWidgetConfiguration(bucket: .primary)),
            for: .usage
        )
    }
}

@Test
func missingMetricsStayExplicitlyUnavailable() {
    #expect(StatusWidget.metric(snapshot: nil) == .unavailable)
    #expect(UsageWidget.metric(snapshot: nil, bucket: .primary) == .unavailable)
    #expect(
        UsageWidget.metric(
            snapshot: HabitatSnapshot(activity: .working, connectionHealth: .online),
            bucket: .primary
        ) == .unavailable
    )
}

@Test
func availableMetricsRemainTyped() {
    let snapshot = HabitatSnapshot(
        activity: .attention,
        connectionHealth: .online,
        primaryRateLimit: RateLimitSummary(usedPercent: 37, resetAt: nil)
    )

    #expect(StatusWidget.metric(snapshot: snapshot) == .activity(.attention))
    #expect(UsageWidget.metric(snapshot: snapshot, bucket: .primary) == .percentage(37))
}

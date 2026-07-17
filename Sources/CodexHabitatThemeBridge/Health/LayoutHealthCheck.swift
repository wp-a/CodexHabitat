import Foundation

struct LayoutHealthSnapshot: Codable, Equatable, Sendable {
    let sidebarVisible: Bool
    let mainSurfaceVisible: Bool
    let composerVisible: Bool
    let composerAcceptsPointerEvents: Bool
    let threadCanScroll: Bool
    let popoversWithinViewport: Bool
    let controlsWithinViewport: Bool
    let horizontalOverflowPixels: Double
}

enum LayoutHealthFailure: String, Equatable, Hashable, Sendable {
    case sidebarMissingOrHidden
    case mainSurfaceMissingOrHidden
    case composerMissingOrHidden
    case composerPointerEventsDisabled
    case threadNotScrollable
    case popoverOutsideViewport
    case controlOutsideViewport
    case horizontalOverflow
}

struct LayoutHealthReport: Equatable, Sendable {
    let failures: [LayoutHealthFailure]
    var passed: Bool { failures.isEmpty }
}

struct LayoutHealthCheck: Sendable {
    let profile: CompatibilityProfile

    func evaluate(_ snapshot: LayoutHealthSnapshot) -> LayoutHealthReport {
        var failures: [LayoutHealthFailure] = []
        if !snapshot.sidebarVisible { failures.append(.sidebarMissingOrHidden) }
        if !snapshot.mainSurfaceVisible { failures.append(.mainSurfaceMissingOrHidden) }
        if !snapshot.composerVisible { failures.append(.composerMissingOrHidden) }
        if !snapshot.composerAcceptsPointerEvents {
            failures.append(.composerPointerEventsDisabled)
        }
        if !snapshot.threadCanScroll { failures.append(.threadNotScrollable) }
        if !snapshot.popoversWithinViewport { failures.append(.popoverOutsideViewport) }
        if !snapshot.controlsWithinViewport { failures.append(.controlOutsideViewport) }
        if snapshot.horizontalOverflowPixels > 1 { failures.append(.horizontalOverflow) }
        return LayoutHealthReport(failures: failures)
    }

    func evaluationScript() -> String {
        let sidebar = Self.javaScriptString(profile.selectors.sidebar)
        let main = Self.javaScriptString(profile.selectors.mainSurface)
        let composer = Self.javaScriptString(profile.selectors.composer)
        let thread = Self.javaScriptString(profile.selectors.threadScroll)
        let popover = Self.javaScriptString(profile.selectors.popover)
        return """
        (() => {
          const visible = (node) => {
            if (!node) return false;
            const style = getComputedStyle(node);
            const rect = node.getBoundingClientRect();
            return style.display !== "none" && style.visibility !== "hidden" &&
              Number(style.opacity || 1) > 0 && rect.width > 0 && rect.height > 0;
          };
          const inside = (node) => {
            if (!node) return false;
            const rect = node.getBoundingClientRect();
            return rect.left >= -1 && rect.top >= -1 &&
              rect.right <= window.innerWidth + 1 && rect.bottom <= window.innerHeight + 1;
          };
          const sidebar = document.querySelector(\(sidebar));
          const main = document.querySelector(\(main));
          const composer = document.querySelector(\(composer));
          const thread = document.querySelector(\(thread));
          const popovers = Array.from(document.querySelectorAll(\(popover))).filter(visible);
          const composerStyle = composer ? getComputedStyle(composer) : null;
          return {
            sidebarVisible: visible(sidebar),
            mainSurfaceVisible: visible(main),
            composerVisible: visible(composer),
            composerAcceptsPointerEvents: !!composerStyle && composerStyle.pointerEvents !== "none",
            threadCanScroll: !!thread && (thread.scrollHeight <= thread.clientHeight + 1 ||
              ["auto", "scroll"].includes(getComputedStyle(thread).overflowY)),
            popoversWithinViewport: popovers.every(inside),
            controlsWithinViewport: [sidebar, main, composer].every(inside),
            horizontalOverflowPixels: Math.max(0,
              document.documentElement.scrollWidth - document.documentElement.clientWidth),
          };
        })()
        """
    }

    private static func javaScriptString(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [value])
        let encoded = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(encoded.dropFirst().dropLast())
    }
}

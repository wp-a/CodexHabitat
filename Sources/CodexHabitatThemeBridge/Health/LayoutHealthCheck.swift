import Foundation

enum LayoutHealthRoute: String, Codable, Equatable, Sendable {
    case home
    case task
}

struct LayoutHealthSnapshot: Codable, Equatable, Sendable {
    let route: LayoutHealthRoute
    let appShellVisible: Bool
    let sidebarVisible: Bool
    let mainSurfaceVisible: Bool
    let headerVisible: Bool
    let composerVisible: Bool
    let composerAcceptsPointerEvents: Bool
    let composerHitTestable: Bool
    let threadCanScroll: Bool
    let requiredSurfaceAnnotationsPresent: Bool
    let popoversWithinViewport: Bool
    let controlsWithinViewport: Bool
    let horizontalOverflowPixels: Double

    init(
        route: LayoutHealthRoute = .task,
        appShellVisible: Bool,
        sidebarVisible: Bool,
        mainSurfaceVisible: Bool,
        headerVisible: Bool,
        composerVisible: Bool,
        composerAcceptsPointerEvents: Bool,
        composerHitTestable: Bool,
        threadCanScroll: Bool,
        requiredSurfaceAnnotationsPresent: Bool,
        popoversWithinViewport: Bool,
        controlsWithinViewport: Bool,
        horizontalOverflowPixels: Double
    ) {
        self.route = route
        self.appShellVisible = appShellVisible
        self.sidebarVisible = sidebarVisible
        self.mainSurfaceVisible = mainSurfaceVisible
        self.headerVisible = headerVisible
        self.composerVisible = composerVisible
        self.composerAcceptsPointerEvents = composerAcceptsPointerEvents
        self.composerHitTestable = composerHitTestable
        self.threadCanScroll = threadCanScroll
        self.requiredSurfaceAnnotationsPresent = requiredSurfaceAnnotationsPresent
        self.popoversWithinViewport = popoversWithinViewport
        self.controlsWithinViewport = controlsWithinViewport
        self.horizontalOverflowPixels = horizontalOverflowPixels
    }
}

enum LayoutHealthFailure: String, Equatable, Hashable, Sendable {
    case appShellMissingOrHidden
    case sidebarMissingOrHidden
    case mainSurfaceMissingOrHidden
    case headerMissingOrHidden
    case composerMissingOrHidden
    case composerPointerEventsDisabled
    case composerHitTestingFailed
    case threadNotScrollable
    case requiredSurfaceAnnotationMissing
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
    let requiresSurfaceAnnotations: Bool

    init(profile: CompatibilityProfile, requiresSurfaceAnnotations: Bool = true) {
        self.profile = profile
        self.requiresSurfaceAnnotations = requiresSurfaceAnnotations
    }

    func evaluate(_ snapshot: LayoutHealthSnapshot) -> LayoutHealthReport {
        var failures: [LayoutHealthFailure] = []
        if !snapshot.appShellVisible { failures.append(.appShellMissingOrHidden) }
        if !snapshot.sidebarVisible { failures.append(.sidebarMissingOrHidden) }
        if !snapshot.mainSurfaceVisible { failures.append(.mainSurfaceMissingOrHidden) }
        if !snapshot.headerVisible { failures.append(.headerMissingOrHidden) }
        if snapshot.route == .task {
            if !snapshot.composerVisible { failures.append(.composerMissingOrHidden) }
            if !snapshot.composerAcceptsPointerEvents {
                failures.append(.composerPointerEventsDisabled)
            }
            if !snapshot.composerHitTestable { failures.append(.composerHitTestingFailed) }
            if !snapshot.threadCanScroll { failures.append(.threadNotScrollable) }
        }
        if requiresSurfaceAnnotations, !snapshot.requiredSurfaceAnnotationsPresent {
            failures.append(.requiredSurfaceAnnotationMissing)
        }
        if !snapshot.popoversWithinViewport { failures.append(.popoverOutsideViewport) }
        if !snapshot.controlsWithinViewport { failures.append(.controlOutsideViewport) }
        if snapshot.horizontalOverflowPixels > 1 { failures.append(.horizontalOverflow) }
        return LayoutHealthReport(failures: failures)
    }

    func evaluationScript() -> String {
        let appShell = profile.selectors.appShell.map(Self.javaScriptString)
        let sidebar = Self.javaScriptString(profile.selectors.sidebar)
        let main = Self.javaScriptString(profile.selectors.mainSurface)
        let header = Self.javaScriptString(profile.selectors.header)
        let composer = Self.javaScriptString(profile.selectors.composer)
        let thread = Self.javaScriptString(profile.selectors.threadScroll)
        let popover = Self.javaScriptString(profile.selectors.popover)
        let homeMarker = Self.javaScriptString(profile.selectors.homeMarker)
        let annotations = Self.javaScriptJSON(HostSurfaceAnnotationPlan(profile: profile).entries)
        let shellLookup = appShell.map { "document.querySelector(\($0))" }
            ?? "document.body"
        return """
        (() => {
          const surfaceEntries = \(annotations);
          const surfaceAttribute = "data-codex-habitat-surface";
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
          const appShell = \(shellLookup);
          const sidebar = document.querySelector(\(sidebar));
          const main = document.querySelector(\(main));
          const header = document.querySelector(\(header));
          const composer = document.querySelector(\(composer));
          const thread = document.querySelector(\(thread));
          const isHome = !!document.querySelector(\(homeMarker));
          const popovers = Array.from(document.querySelectorAll(\(popover))).filter(visible);
          const composerStyle = composer ? getComputedStyle(composer) : null;
          const composerRect = composer ? composer.getBoundingClientRect() : null;
          const composerHit = composerRect ? document.elementFromPoint(
            composerRect.left + composerRect.width / 2,
            composerRect.top + composerRect.height / 2
          ) : null;
          const expectedSurfaces = new Map();
          for (const entry of surfaceEntries) {
            for (const node of document.querySelectorAll(entry.selector)) {
              if (!expectedSurfaces.has(node)) expectedSurfaces.set(node, entry.surface);
            }
          }
          const requiredSurfaceAnnotationsPresent = Array.from(expectedSurfaces).every(
            ([node, surface]) => node.getAttribute(surfaceAttribute) === surface
          );
          return {
            route: isHome ? "home" : "task",
            appShellVisible: visible(appShell),
            sidebarVisible: visible(sidebar),
            mainSurfaceVisible: visible(main),
            headerVisible: visible(header),
            composerVisible: visible(composer),
            composerAcceptsPointerEvents: !!composerStyle && composerStyle.pointerEvents !== "none",
            composerHitTestable: !!composerHit &&
              (composerHit === composer || composer.contains(composerHit)),
            threadCanScroll: visible(thread) && (thread.scrollHeight <= thread.clientHeight + 1 ||
              ["auto", "scroll"].includes(getComputedStyle(thread).overflowY)),
            requiredSurfaceAnnotationsPresent,
            popoversWithinViewport: popovers.every(inside),
            controlsWithinViewport:
              (isHome ? [sidebar, main, header] : [sidebar, main, header, composer]).every(inside),
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

    private static func javaScriptJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return encoded
    }
}

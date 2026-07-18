import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func clientListsValidatedPageTargetsAndIgnoresWorkers() async throws {
    let page = CDPTarget(
        id: "page-1",
        type: "page",
        title: "Codex",
        url: URL(string: "app://codex/index.html")!,
        webSocketDebuggerURL: URL(
            string: "ws://127.0.0.1:55000/devtools/page/page-1"
        )!
    )
    let worker = CDPTarget(
        id: "worker-1",
        type: "worker",
        title: "Worker",
        url: URL(string: "app://codex/worker")!,
        webSocketDebuggerURL: URL(
            string: "ws://127.0.0.1:55000/devtools/page/worker-1"
        )!
    )
    let transport = StubCDPTransport(listData: try JSONEncoder().encode([worker, page]))
    let client = CDPClient(port: 55_000, transport: transport)

    let targets = try await client.listPageTargets()

    #expect(targets == [page])
    #expect(transport.requestedEndpoints == [
        URL(string: "http://127.0.0.1:55000/json/list")!,
    ])
}

@Test
func clientKeepsTheCodexMainPageWhenOfficialAuxiliaryPagesArePresent() async throws {
    let mainPage = CDPTarget(
        id: "main-page",
        type: "page",
        title: "Codex",
        url: URL(
            string: "app://-/index.html?initialRoute=%2Flocal%2Fworkspace"
        )!,
        webSocketDebuggerURL: URL(
            string: "ws://127.0.0.1:55000/devtools/page/main-page"
        )!
    )
    let petSurface = CDPTarget(
        id: "pet-surface",
        type: "page",
        title: "Pet Surface",
        url: URL(
            string: "app://-/avatar-overlay-composition-surface.html?surfaceId=pet-1"
        )!,
        webSocketDebuggerURL: URL(
            string: "ws://127.0.0.1:55000/devtools/page/pet-surface"
        )!
    )
    let auxiliaryRoutes = [
        "/avatar-overlay",
        "/hotkey-window/thread/active",
        "/global-dictation",
        "/chatgpt/quick-chat-prewarm",
        "/debug",
    ].enumerated().map { index, route in
        let id = "auxiliary-\(index)"
        return CDPTarget(
            id: id,
            type: "page",
            title: "Auxiliary",
            url: URL(
                string: "app://-/index.html?initialRoute=\(route)"
            )!,
            webSocketDebuggerURL: URL(
                string: "ws://127.0.0.1:55000/devtools/page/\(id)"
            )!
        )
    }
    let transport = StubCDPTransport(
        listData: try JSONEncoder().encode(
            [petSurface] + auxiliaryRoutes + [mainPage]
        )
    )
    let client = CDPClient(port: 55_000, transport: transport)

    let targets = try await client.listPageTargets()

    #expect(targets == [mainPage])
}

@Test
func clientFailsClosedWhenAnyPageHasAnUnsafeDebuggerEndpoint() async throws {
    let mainPage = validTarget()
    let wrongPort = CDPTarget(
        id: "wrong-port",
        type: "page",
        title: "Auxiliary",
        url: URL(
            string: "app://-/avatar-overlay-composition-surface.html?surfaceId=pet-1"
        )!,
        webSocketDebuggerURL: URL(
            string: "ws://127.0.0.1:55001/devtools/page/wrong-port"
        )!
    )
    let transport = StubCDPTransport(
        listData: try JSONEncoder().encode([wrongPort, mainPage])
    )
    let client = CDPClient(port: 55_000, transport: transport)

    await #expect(throws: CDPTargetValidationError.wrongPort) {
        _ = try await client.listPageTargets()
    }
}

@Test
func clientFailsClosedWhenAnIndexPageHasAnUnknownQuery() async throws {
    let mainPage = validTarget()
    let unknownQuery = CDPTarget(
        id: "unknown-query",
        type: "page",
        title: "Codex",
        url: URL(string: "app://-/index.html?tracking=secret")!,
        webSocketDebuggerURL: URL(
            string: "ws://127.0.0.1:55000/devtools/page/unknown-query"
        )!
    )
    let transport = StubCDPTransport(
        listData: try JSONEncoder().encode([unknownQuery, mainPage])
    )
    let client = CDPClient(port: 55_000, transport: transport)

    await #expect(throws: CDPTargetValidationError.queryOrFragmentNotAllowed) {
        _ = try await client.listPageTargets()
    }
}

@Test
func styleInstallAndRemovalUseStructuredRuntimeEvaluation() async throws {
    let target = validTarget()
    let transport = StubCDPTransport(listData: Data("[]".utf8))
    let client = CDPClient(port: 55_000, transport: transport)
    let css = "html::before { content: \"</style><script>blocked()</script>\"; }"

    try await client.installStyle(
        css,
        homeMarker: "[data-testid=\"home-icon\"]",
        on: target
    )
    try await client.removeStyle(from: target)

    #expect(transport.messages.count == 4)
    let install = try #require(
        JSONSerialization.jsonObject(with: transport.messages[0]) as? [String: Any]
    )
    #expect(install["method"] as? String == "Runtime.evaluate")
    let installParams = try #require(install["params"] as? [String: Any])
    let expression = try #require(installParams["expression"] as? String)
    #expect(expression.contains("codex-habitat-theme-style"))
    let assignment = try #require(
        expression.split(separator: "\n").first { $0.contains("style.textContent = ") }
    )
    let literal = assignment
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .dropFirst("style.textContent = ".count)
        .dropLast()
    let decoded = try #require(
        JSONSerialization.jsonObject(with: Data("[\(literal)]".utf8)) as? [String]
    )
    #expect(decoded == [css])
    #expect(!expression.contains("eval("))

    let bootstrap = try #require(
        JSONSerialization.jsonObject(with: transport.messages[1]) as? [String: Any]
    )
    #expect(bootstrap["method"] as? String == "Page.addScriptToEvaluateOnNewDocument")
    let bootstrapParams = try #require(bootstrap["params"] as? [String: Any])
    let source = try #require(bootstrapParams["source"] as? String)
    #expect(source.contains("MutationObserver"))
    #expect(source.contains("codex-habitat-theme-style"))
    #expect(source.contains("__codexHabitatRouteObserver"))
    #expect(source.contains("__codexHabitatRouteTimer"))
    #expect(source.contains("new MutationObserver(scheduleRouteUpdate)"))
    #expect(source.contains("setTimeout"))
    #expect(source.contains("120"))
    #expect(source.contains("if (currentRoute !== route)"))
    #expect(source.contains("data-codex-habitat-route"))
    #expect(source.contains("[data-testid=\\\"home-icon\\\"]"))
    #expect(!source.contains("innerText"))
    #expect(!source.contains("innerHTML"))
    #expect(source.contains("blocked()"))
    #expect(!source.contains("</style><script>"))

    let removeBootstrap = try #require(
        JSONSerialization.jsonObject(with: transport.messages[2]) as? [String: Any]
    )
    #expect(removeBootstrap["method"] as? String == "Page.removeScriptToEvaluateOnNewDocument")
    let removeBootstrapParams = try #require(removeBootstrap["params"] as? [String: Any])
    #expect(removeBootstrapParams["identifier"] as? String == "bootstrap-1")

    let removal = try #require(
        JSONSerialization.jsonObject(with: transport.messages[3]) as? [String: Any]
    )
    let removalParams = try #require(removal["params"] as? [String: Any])
    let removalExpression = try #require(removalParams["expression"] as? String)
    #expect(removalExpression.contains("__codexHabitatRouteObserver"))
    #expect(removalExpression.contains("__codexHabitatRouteTimer"))
    #expect(removalExpression.contains("clearTimeout"))
    #expect(removalExpression.contains("data-codex-habitat-route"))
    #expect(removalExpression.contains("removeAttribute"))
}

@Test
func reinstallingAStyleReplacesThePreviousNavigationBootstrap() async throws {
    let target = validTarget()
    let transport = StubCDPTransport(listData: Data("[]".utf8))
    let client = CDPClient(port: 55_000, transport: transport)

    try await client.installStyle("body { color: red; }", homeMarker: "main", on: target)
    try await client.installStyle("body { color: blue; }", homeMarker: "main", on: target)

    #expect(transport.messages.count == 5)
    let methods = try transport.messages.map { message in
        let object = try #require(
            JSONSerialization.jsonObject(with: message) as? [String: Any]
        )
        return try #require(object["method"] as? String)
    }
    #expect(methods == [
        "Runtime.evaluate",
        "Page.addScriptToEvaluateOnNewDocument",
        "Page.removeScriptToEvaluateOnNewDocument",
        "Runtime.evaluate",
        "Page.addScriptToEvaluateOnNewDocument",
    ])
}

@Test
func healthSnapshotAndScreenshotAreDecodedFromCDPValues() async throws {
    let target = validTarget()
    let snapshot = LayoutHealthSnapshot(
        sidebarVisible: true,
        mainSurfaceVisible: true,
        composerVisible: true,
        composerAcceptsPointerEvents: true,
        threadCanScroll: true,
        popoversWithinViewport: true,
        controlsWithinViewport: true,
        horizontalOverflowPixels: 0
    )
    let screenshot = Data("png fixture".utf8)
    let transport = StubCDPTransport(
        listData: Data("[]".utf8),
        evaluatedValue: try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(snapshot)
        ),
        screenshotData: screenshot
    )
    let client = CDPClient(port: 55_000, transport: transport)

    let decoded = try await client.healthSnapshot(
        on: target,
        check: LayoutHealthCheck(profile: try currentProfile())
    )
    let captured = try await client.captureScreenshot(of: target)

    #expect(decoded == snapshot)
    #expect(captured == screenshot)
}

private final class StubCDPTransport: CDPTransport, @unchecked Sendable {
    let listData: Data
    let evaluatedValue: Any
    let screenshotData: Data
    var requestedEndpoints: [URL] = []
    var messages: [Data] = []

    init(
        listData: Data,
        evaluatedValue: Any = ["installed": true],
        screenshotData: Data = Data()
    ) {
        self.listData = listData
        self.evaluatedValue = evaluatedValue
        self.screenshotData = screenshotData
    }

    func fetch(endpoint: URL) async throws -> CDPHTTPResponse {
        requestedEndpoints.append(endpoint)
        return CDPHTTPResponse(statusCode: 200, finalURL: endpoint, data: listData)
    }

    func exchange(webSocketURL: URL, message: Data) async throws -> Data {
        messages.append(message)
        let request = try #require(
            JSONSerialization.jsonObject(with: message) as? [String: Any]
        )
        let id = request["id"] as? Int ?? 1
        let method = request["method"] as? String
        let result: [String: Any]
        if method == "Page.captureScreenshot" {
            result = ["data": screenshotData.base64EncodedString()]
        } else if method == "Page.addScriptToEvaluateOnNewDocument" {
            result = ["identifier": "bootstrap-1"]
        } else {
            result = ["result": ["type": "object", "value": evaluatedValue]]
        }
        return try JSONSerialization.data(withJSONObject: ["id": id, "result": result])
    }
}

private func validTarget() -> CDPTarget {
    CDPTarget(
        id: "page-1",
        type: "page",
        title: "Codex",
        url: URL(string: "app://codex/index.html")!,
        webSocketDebuggerURL: URL(
            string: "ws://127.0.0.1:55000/devtools/page/page-1"
        )!
    )
}

private func currentProfile() throws -> CompatibilityProfile {
    try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
}

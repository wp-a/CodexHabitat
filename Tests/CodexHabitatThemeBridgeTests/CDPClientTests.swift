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
func styleInstallAndRemovalUseStructuredRuntimeEvaluation() async throws {
    let target = validTarget()
    let transport = StubCDPTransport(listData: Data("[]".utf8))
    let client = CDPClient(port: 55_000, transport: transport)
    let css = "html::before { content: \"</style><script>blocked()</script>\"; }"

    try await client.installStyle(css, on: target)
    try await client.removeStyle(from: target)

    #expect(transport.messages.count == 3)
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
    #expect(source.contains("blocked()"))
    #expect(!source.contains("</style><script>"))

    let removal = try #require(
        JSONSerialization.jsonObject(with: transport.messages[2]) as? [String: Any]
    )
    let removalParams = try #require(removal["params"] as? [String: Any])
    #expect((removalParams["expression"] as? String)?.contains("removeAttribute") == true)
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

import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func validLoopbackPageTargetUsesTheOwnedPortAndAppScheme() throws {
    let validator = CDPTargetValidator(port: 55_000)
    let target = CDPTarget(
        id: "page-1",
        type: "page",
        title: "Codex",
        url: URL(string: "app://codex/index.html")!,
        webSocketDebuggerURL: URL(
            string: "ws://127.0.0.1:55000/devtools/page/page-1"
        )!
    )

    #expect(try validator.validate(target) == target)
    #expect(
        try validator.validateListEndpoint(
            URL(string: "http://127.0.0.1:55000/json/list")!
        ) == URL(string: "http://127.0.0.1:55000/json/list")!
    )
}

@Test(arguments: [
    (
        "ws://192.168.1.9:55000/devtools/page/page-1",
        "app://codex/index.html",
        CDPTargetValidationError.nonLoopbackURL
    ),
    (
        "ws://127.0.0.1:55001/devtools/page/page-1",
        "app://codex/index.html",
        CDPTargetValidationError.wrongPort
    ),
    (
        "ws://user:pass@127.0.0.1:55000/devtools/page/page-1",
        "app://codex/index.html",
        CDPTargetValidationError.credentialsNotAllowed
    ),
    (
        "ws://127.0.0.1:55000/devtools/page/page-1?token=secret",
        "app://codex/index.html",
        CDPTargetValidationError.queryOrFragmentNotAllowed
    ),
    (
        "ws://127.0.0.1:55000/devtools/page/page-1",
        "https://example.com/",
        CDPTargetValidationError.nonAppPage
    ),
])
func unsafeTargetsAreRejected(
    webSocket: String,
    page: String,
    expected: CDPTargetValidationError
) {
    let validator = CDPTargetValidator(port: 55_000)
    let target = CDPTarget(
        id: "page-1",
        type: "page",
        title: "Codex",
        url: URL(string: page)!,
        webSocketDebuggerURL: URL(string: webSocket)!
    )

    #expect(throws: expected) {
        try validator.validate(target)
    }
}

@Test
func nonPageTargetAndUnexpectedDevToolsPathAreRejected() {
    let validator = CDPTargetValidator(port: 55_000)
    #expect(throws: CDPTargetValidationError.unsupportedTargetType("worker")) {
        try validator.validate(CDPTarget(
            id: "worker-1",
            type: "worker",
            title: "Worker",
            url: URL(string: "app://codex/worker")!,
            webSocketDebuggerURL: URL(
                string: "ws://127.0.0.1:55000/devtools/page/worker-1"
            )!
        ))
    }
    #expect(throws: CDPTargetValidationError.invalidDevToolsPath) {
        try validator.validate(CDPTarget(
            id: "page-1",
            type: "page",
            title: "Codex",
            url: URL(string: "app://codex/index.html")!,
            webSocketDebuggerURL: URL(string: "ws://127.0.0.1:55000/other")!
        ))
    }
}

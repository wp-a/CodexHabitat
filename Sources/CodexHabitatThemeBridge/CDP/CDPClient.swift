import Foundation

struct CDPHTTPResponse: Sendable {
    let statusCode: Int
    let finalURL: URL
    let data: Data
}

protocol CDPTransport: Sendable {
    func fetch(endpoint: URL) async throws -> CDPHTTPResponse
    func exchange(webSocketURL: URL, message: Data) async throws -> Data
}

enum CDPClientError: Error, Equatable {
    case invalidHTTPResponse
    case responseTooLarge
    case invalidTargetList
    case invalidCommand
    case commandFailed
    case invalidResult
    case invalidScreenshot
    case timeout
}

actor CDPClient {
    private let port: UInt16
    private let validator: CDPTargetValidator
    private let transport: any CDPTransport
    private var nextCommandID = 1

    init(
        port: UInt16,
        transport: (any CDPTransport)? = nil
    ) {
        self.port = port
        validator = CDPTargetValidator(port: port)
        self.transport = transport ?? LiveCDPTransport(port: port)
    }

    func listPageTargets() async throws -> [CDPTarget] {
        let endpoint = try validator.validateListEndpoint(
            URL(string: "http://127.0.0.1:\(port)/json/list")!
        )
        let response = try await transport.fetch(endpoint: endpoint)
        guard response.statusCode == 200,
              response.data.count <= 1024 * 1024,
              try validator.validateListEndpoint(response.finalURL) == endpoint
        else {
            throw CDPClientError.invalidHTTPResponse
        }
        let targets: [CDPTarget]
        do {
            targets = try JSONDecoder().decode([CDPTarget].self, from: response.data)
        } catch {
            throw CDPClientError.invalidTargetList
        }
        var mainPages: [CDPTarget] = []
        for target in targets where target.type == "page" {
            switch try validator.classification(of: target) {
            case .mainPage:
                mainPages.append(target)
            case .officialAuxiliaryPage:
                continue
            }
        }
        return mainPages
    }

    func installStyle(
        _ css: String,
        homeMarker: String,
        on target: CDPTarget
    ) async throws {
        _ = try validator.validate(target)
        let expression = Self.styleInstallerExpression(
            css: css,
            homeMarker: homeMarker,
            reportsResult: true
        )
        _ = try await evaluate(expression, on: target)
        _ = try await command(
            method: "Page.addScriptToEvaluateOnNewDocument",
            parameters: [
                "source": Self.styleInstallerExpression(
                    css: css,
                    homeMarker: homeMarker,
                    reportsResult: false
                ),
            ],
            target: target
        )
    }

    func isStyleInstalled(on target: CDPTarget) async throws -> Bool {
        _ = try validator.validate(target)
        let value = try await evaluate(
            "document.documentElement.getAttribute(\"data-codex-habitat-theme\") === \"1\"",
            on: target
        )
        guard let installed = value as? Bool else { throw CDPClientError.invalidResult }
        return installed
    }

    private static func styleInstallerExpression(
        css: String,
        homeMarker: String,
        reportsResult: Bool
    ) -> String {
        let cssLiteral = javaScriptString(css)
        let homeMarkerLiteral = javaScriptString(homeMarker)
        return """
        (() => {
          const homeMarker = \(homeMarkerLiteral);
          const updateRoute = () => {
            const route = document.querySelector(homeMarker) ? "home" : "task";
            document.documentElement.setAttribute("data-codex-habitat-route", route);
          };
          const install = () => {
            const id = "codex-habitat-theme-style";
            let style = document.getElementById(id);
            if (!style) {
              style = document.createElement("style");
              style.id = id;
              (document.head || document.documentElement).appendChild(style);
            }
            style.textContent = \(cssLiteral);
            document.documentElement.setAttribute("data-codex-habitat-theme", "1");
            updateRoute();
            globalThis.__codexHabitatThemeObserver?.disconnect();
            const observer = new MutationObserver(() => {
              if (!document.getElementById(id)) install();
            });
            observer.observe(document.documentElement, { childList: true, subtree: true });
            globalThis.__codexHabitatThemeObserver = observer;
            globalThis.__codexHabitatRouteObserver?.disconnect();
            const routeObserver = new MutationObserver(updateRoute);
            routeObserver.observe(document.documentElement, {
              childList: true,
              subtree: true,
              attributes: false,
              characterData: false,
            });
            globalThis.__codexHabitatRouteObserver = routeObserver;
            return { installed: true };
          };
          if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", install, { once: true });
            return { installed: true, pending: true };
          }
          return install();
        })()
        """
    }

    func removeStyle(from target: CDPTarget) async throws {
        _ = try validator.validate(target)
        let expression = """
        (() => {
          globalThis.__codexHabitatThemeObserver?.disconnect();
          delete globalThis.__codexHabitatThemeObserver;
          globalThis.__codexHabitatRouteObserver?.disconnect();
          delete globalThis.__codexHabitatRouteObserver;
          document.getElementById("codex-habitat-theme-style")?.remove();
          document.documentElement.removeAttribute("data-codex-habitat-theme");
          document.documentElement.removeAttribute("data-codex-habitat-route");
          return { removed: true };
        })()
        """
        _ = try await evaluate(expression, on: target)
    }

    func healthSnapshot(
        on target: CDPTarget,
        check: LayoutHealthCheck
    ) async throws -> LayoutHealthSnapshot {
        let value = try await evaluate(check.evaluationScript(), on: target)
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let snapshot = try? JSONDecoder().decode(LayoutHealthSnapshot.self, from: data)
        else {
            throw CDPClientError.invalidResult
        }
        return snapshot
    }

    func captureScreenshot(of target: CDPTarget) async throws -> Data {
        _ = try validator.validate(target)
        let response = try await command(
            method: "Page.captureScreenshot",
            parameters: ["format": "png", "fromSurface": true],
            target: target
        )
        guard let encoded = response["data"] as? String,
              let data = Data(base64Encoded: encoded),
              data.count <= 32 * 1024 * 1024
        else {
            throw CDPClientError.invalidScreenshot
        }
        return data
    }

    private func evaluate(_ expression: String, on target: CDPTarget) async throws -> Any {
        let response = try await command(
            method: "Runtime.evaluate",
            parameters: [
                "expression": expression,
                "returnByValue": true,
                "awaitPromise": true,
            ],
            target: target
        )
        guard response["exceptionDetails"] == nil,
              let remoteObject = response["result"] as? [String: Any],
              let value = remoteObject["value"]
        else {
            throw CDPClientError.commandFailed
        }
        return value
    }

    private func command(
        method: String,
        parameters: [String: Any],
        target: CDPTarget
    ) async throws -> [String: Any] {
        let id = nextCommandID
        nextCommandID += 1
        let object: [String: Any] = ["id": id, "method": method, "params": parameters]
        guard JSONSerialization.isValidJSONObject(object) else {
            throw CDPClientError.invalidCommand
        }
        let message = try JSONSerialization.data(withJSONObject: object)
        let responseData = try await transport.exchange(
            webSocketURL: target.webSocketDebuggerURL,
            message: message
        )
        guard responseData.count <= 2 * 1024 * 1024,
              let response = try JSONSerialization.jsonObject(with: responseData)
                as? [String: Any],
              response["id"] as? Int == id,
              response["error"] == nil,
              let result = response["result"] as? [String: Any]
        else {
            throw CDPClientError.commandFailed
        }
        return result
    }

    private static func javaScriptString(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [value])
        let encoded = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(encoded.dropFirst().dropLast())
    }
}

protocol CDPControlling: Sendable {
    func listPageTargets() async throws -> [CDPTarget]
    func installStyle(
        _ css: String,
        homeMarker: String,
        on target: CDPTarget
    ) async throws
    func isStyleInstalled(on target: CDPTarget) async throws -> Bool
    func removeStyle(from target: CDPTarget) async throws
    func healthSnapshot(
        on target: CDPTarget,
        check: LayoutHealthCheck
    ) async throws -> LayoutHealthSnapshot
    func captureScreenshot(of target: CDPTarget) async throws -> Data
}

extension CDPClient: CDPControlling {}

protocol CDPClientProviding: Sendable {
    func client(port: UInt16) -> any CDPControlling
}

struct LiveCDPClientProvider: CDPClientProviding {
    func client(port: UInt16) -> any CDPControlling {
        CDPClient(port: port)
    }
}

private final class LiveCDPTransport: NSObject, CDPTransport, @unchecked Sendable {
    private let port: UInt16
    private let session: URLSession

    init(port: UInt16) {
        self.port = port
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        session = URLSession(
            configuration: configuration,
            delegate: CDPLoopbackRedirectDelegate(port: port),
            delegateQueue: nil
        )
    }

    func fetch(endpoint: URL) async throws -> CDPHTTPResponse {
        var request = URLRequest(url: endpoint, timeoutInterval: 3)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              let finalURL = response.url,
              data.count <= 1024 * 1024
        else {
            throw CDPClientError.invalidHTTPResponse
        }
        return CDPHTTPResponse(
            statusCode: response.statusCode,
            finalURL: finalURL,
            data: data
        )
    }

    func exchange(webSocketURL: URL, message: Data) async throws -> Data {
        guard let requestObject = try JSONSerialization.jsonObject(with: message)
                as? [String: Any],
              let expectedID = requestObject["id"] as? Int,
              let text = String(data: message, encoding: .utf8)
        else {
            throw CDPClientError.invalidCommand
        }
        var request = URLRequest(url: webSocketURL, timeoutInterval: 3)
        request.setValue("http://127.0.0.1:\(port)", forHTTPHeaderField: "Origin")
        let task = session.webSocketTask(with: request)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }
        try await task.send(.string(text))

        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                for _ in 0..<64 {
                    let message = try await task.receive()
                    let data: Data
                    switch message {
                    case let .data(value): data = value
                    case let .string(value): data = Data(value.utf8)
                    @unknown default: throw CDPClientError.commandFailed
                    }
                    guard data.count <= 2 * 1024 * 1024 else {
                        throw CDPClientError.responseTooLarge
                    }
                    if let object = try JSONSerialization.jsonObject(with: data)
                        as? [String: Any], object["id"] as? Int == expectedID {
                        return data
                    }
                }
                throw CDPClientError.commandFailed
            }
            group.addTask {
                try await Task.sleep(for: .seconds(3))
                throw CDPClientError.timeout
            }
            guard let result = try await group.next() else {
                throw CDPClientError.commandFailed
            }
            group.cancelAll()
            return result
        }
    }
}

private final class CDPLoopbackRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let port: UInt16

    init(port: UInt16) { self.port = port }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              ["http", "ws"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.lowercased() == "127.0.0.1",
              url.port == Int(port),
              url.user == nil,
              url.password == nil
        else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

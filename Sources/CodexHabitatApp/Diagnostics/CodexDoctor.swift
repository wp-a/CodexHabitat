import CodexConnector
import Foundation
import HabitatCore

enum CodexDoctor {
    static func run() async -> Int32 {
        do {
            let root = try applicationSupportRoot()
            let salt = try EventHashSaltStore(
                root: root.appending(path: "Private", directoryHint: .isDirectory)
            ).loadOrCreate()
            let client = CodexControlClient(
                transport: ProcessTransport(),
                sanitizer: CodexEventSanitizer(salt: salt)
            )

            do {
                try await client.connect()
            } catch {
                print("connection: \(safeFailure(for: error))")
                print("loaded-threads: unavailable")
                print("rate-limits: unavailable")
                return 1
            }

            print("connection: connected")
            var succeeded = true
            do {
                let threads = try await client.readLoadedThreadsSummary()
                print("loaded-threads: \(threads.count)")
            } catch {
                print("loaded-threads: unavailable-\(safeFailure(for: error))")
                succeeded = false
            }
            do {
                let limits = try await client.readRateLimits()
                print("rate-limits: \(limits == nil ? "unavailable" : "available")")
            } catch {
                print("rate-limits: unavailable")
            }
            await client.disconnect()
            return succeeded ? 0 : 1
        } catch {
            print("connection: \(safeFailure(for: error))")
            print("loaded-threads: unavailable")
            print("rate-limits: unavailable")
            return 1
        }
    }

    private static func applicationSupportRoot() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appending(path: "Codex Habitat", directoryHint: .isDirectory)
    }

    private static func safeFailure(for error: any Error) -> String {
        switch error {
        case CodexControlClientError.invalidHandshake:
            "protocol-mismatch"
        case let CodexControlClientError.serverError(code):
            "server-error-\(code)"
        case CodexControlClientError.unexpectedResponse,
             CodexControlClientError.notConnected,
             CodexControlClientError.alreadyConnected:
            "protocol-error"
        case CodexControlClientError.transportClosed,
             is ProcessTransportError:
            "codex-unavailable"
        case is JSONRPCCodecError,
             is WebSocketCodecError,
             is ReadMethodAllowlistError:
            "protocol-error"
        default:
            "connection-failed"
        }
    }
}

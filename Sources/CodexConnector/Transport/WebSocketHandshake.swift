import CryptoKit
import Foundation

public enum WebSocketHandshake {
    public static func request(host: String, path: String, key: String) -> Data {
        let headers = [
            "GET \(path) HTTP/1.1",
            "Host: \(host)",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Key: \(key)",
            "Sec-WebSocket-Version: 13",
        ]
        return Data((headers.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }

    public static func validate(response: Data, key: String) throws -> Bool {
        guard let text = String(data: response, encoding: .utf8) else { return false }
        let lines = text.components(separatedBy: "\r\n")
        guard lines.first?.contains(" 101 ") == true else { return false }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        guard headers["upgrade"]?.lowercased() == "websocket" else { return false }
        guard headers["connection"]?.lowercased().contains("upgrade") == true else { return false }
        return headers["sec-websocket-accept"] == expectedAccept(for: key)
    }

    private static func expectedAccept(for key: String) -> String {
        let source = Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8)
        return Data(Insecure.SHA1.hash(data: source)).base64EncodedString()
    }
}

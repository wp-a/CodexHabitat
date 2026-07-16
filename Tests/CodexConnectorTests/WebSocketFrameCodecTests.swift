import Foundation
import Testing
@testable import CodexConnector

@Test
func clientTextFrameUsesRFCMasking() throws {
    let encoded = try WebSocketFrameEncoder.clientFrame(
        opcode: .text,
        payload: Data("Hello".utf8),
        maskKey: [0x37, 0xfa, 0x21, 0x3d]
    )

    #expect(encoded == Data([0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58]))
}

@Test
func serverTextFrameDecodesWithoutMasking() throws {
    var decoder = WebSocketFrameDecoder()
    let events = try decoder.append(Data([0x81, 0x05]) + Data("Hello".utf8))

    #expect(events == [.text(Data("Hello".utf8))])
}

@Test
func decoderSupportsSixteenBitPayloadLength() throws {
    let payload = Data(repeating: 0x61, count: 126)
    var decoder = WebSocketFrameDecoder()
    let events = try decoder.append(Data([0x82, 0x7e, 0x00, 0x7e]) + payload)

    #expect(events == [.binary(payload)])
}

@Test
func decoderSupportsSixtyFourBitPayloadLength() throws {
    let payload = Data(repeating: 0x62, count: 66_000)
    var header = Data([0x82, 0x7f])
    header.append(contentsOf: UInt64(payload.count).bigEndianBytes)
    var decoder = WebSocketFrameDecoder()

    let events = try decoder.append(header + payload)

    #expect(events == [.binary(payload)])
}

@Test
func fragmentedTextFramesAreReassembled() throws {
    var decoder = WebSocketFrameDecoder()

    #expect(try decoder.append(Data([0x01, 0x03]) + Data("Hel".utf8)).isEmpty)
    let events = try decoder.append(Data([0x80, 0x02]) + Data("lo".utf8))

    #expect(events == [.text(Data("Hello".utf8))])
}

@Test
func pingRequestsAMatchingPong() throws {
    var decoder = WebSocketFrameDecoder()
    let payload = Data("still-here".utf8)

    let events = try decoder.append(Data([0x89, UInt8(payload.count)]) + payload)

    #expect(events == [.pongRequired(payload)])
}

@Test
func closeIsSurfaced() throws {
    var decoder = WebSocketFrameDecoder()
    let events = try decoder.append(Data([0x88, 0x00]))

    #expect(events == [.closed(Data())])
}

@Test
func invalidReservedBitsAreRejected() {
    var decoder = WebSocketFrameDecoder()

    #expect(throws: WebSocketCodecError.reservedBitsSet) {
        try decoder.append(Data([0xc1, 0x00]))
    }
}

@Test
func oversizedFramesAreRejectedBeforePayloadArrives() {
    var decoder = WebSocketFrameDecoder(maxMessageSize: 1_024)
    let oversizedHeader = Data([0x82, 0x7e, 0x08, 0x00])

    #expect(throws: WebSocketCodecError.messageTooLarge) {
        try decoder.append(oversizedHeader)
    }
}

@Test
func handshakeMatchesRFCExample() throws {
    let key = "dGhlIHNhbXBsZSBub25jZQ=="
    let response = Data(
        """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
        \r
        """.utf8
    )

    #expect(try WebSocketHandshake.validate(response: response, key: key))
}

@Test
func handshakeRequestUsesLocalControlPlaneHeaders() {
    let request = WebSocketHandshake.request(
        host: "localhost",
        path: "/",
        key: "fixed-key"
    )
    let text = String(decoding: request, as: UTF8.self)

    #expect(text.hasPrefix("GET / HTTP/1.1\r\n"))
    #expect(text.contains("Host: localhost\r\n"))
    #expect(text.contains("Upgrade: websocket\r\n"))
    #expect(text.contains("Sec-WebSocket-Key: fixed-key\r\n"))
    #expect(text.hasSuffix("\r\n\r\n"))
}

private extension UInt64 {
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: bigEndian) { Array($0) }
    }
}

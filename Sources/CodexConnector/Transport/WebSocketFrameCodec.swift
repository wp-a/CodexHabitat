import Foundation
import Security

public enum WebSocketOpcode: UInt8, Sendable {
    case continuation = 0x0
    case text = 0x1
    case binary = 0x2
    case close = 0x8
    case ping = 0x9
    case pong = 0xa

    var isControl: Bool {
        rawValue >= 0x8
    }
}

public enum WebSocketEvent: Equatable, Sendable {
    case text(Data)
    case binary(Data)
    case pongRequired(Data)
    case pong(Data)
    case closed(Data)
}

public enum WebSocketCodecError: Error, Equatable {
    case invalidOpcode
    case invalidMaskKey
    case randomMaskFailed
    case reservedBitsSet
    case maskedServerFrame
    case fragmentedControlFrame
    case controlFrameTooLarge
    case unexpectedContinuation
    case unexpectedDataFrame
    case invalidPayloadLength
    case messageTooLarge
}

public enum WebSocketFrameEncoder {
    public static func clientFrame(
        opcode: WebSocketOpcode,
        payload: Data,
        isFinal: Bool = true,
        maskKey: [UInt8]? = nil
    ) throws -> Data {
        if opcode.isControl {
            guard isFinal else { throw WebSocketCodecError.fragmentedControlFrame }
            guard payload.count <= 125 else { throw WebSocketCodecError.controlFrameTooLarge }
        }

        let mask = try maskKey ?? secureMaskKey()
        guard mask.count == 4 else { throw WebSocketCodecError.invalidMaskKey }

        var frame = Data()
        frame.append((isFinal ? 0x80 : 0x00) | opcode.rawValue)
        appendLength(payload.count, masked: true, to: &frame)
        frame.append(contentsOf: mask)
        frame.append(
            contentsOf: payload.enumerated().map { index, byte in
                byte ^ mask[index % mask.count]
            }
        )
        return frame
    }

    private static func secureMaskKey() throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw WebSocketCodecError.randomMaskFailed
        }
        return bytes
    }

    private static func appendLength(_ length: Int, masked: Bool, to frame: inout Data) {
        let maskBit: UInt8 = masked ? 0x80 : 0
        if length <= 125 {
            frame.append(maskBit | UInt8(length))
        } else if length <= Int(UInt16.max) {
            frame.append(maskBit | 126)
            frame.append(contentsOf: UInt16(length).bigEndianBytes)
        } else {
            frame.append(maskBit | 127)
            frame.append(contentsOf: UInt64(length).bigEndianBytes)
        }
    }
}

public struct WebSocketFrameDecoder: Sendable {
    private let maxMessageSize: Int
    private var buffer = Data()
    private var fragmentedOpcode: WebSocketOpcode?
    private var fragmentedPayload = Data()

    public init(maxMessageSize: Int = 1_048_576) {
        self.maxMessageSize = maxMessageSize
    }

    public mutating func append(_ data: Data) throws -> [WebSocketEvent] {
        buffer.append(data)
        var events: [WebSocketEvent] = []

        while let frame = try nextFrame() {
            if let event = try consume(frame) {
                events.append(event)
            }
        }
        return events
    }

    private mutating func nextFrame() throws -> Frame? {
        guard buffer.count >= 2 else { return nil }
        let first = buffer[buffer.startIndex]
        let second = buffer[buffer.index(after: buffer.startIndex)]

        guard first & 0x70 == 0 else { throw WebSocketCodecError.reservedBitsSet }
        guard let opcode = WebSocketOpcode(rawValue: first & 0x0f) else {
            throw WebSocketCodecError.invalidOpcode
        }
        guard second & 0x80 == 0 else { throw WebSocketCodecError.maskedServerFrame }

        let isFinal = first & 0x80 != 0
        var headerLength = 2
        let shortLength = Int(second & 0x7f)
        let payloadLength: Int

        switch shortLength {
        case 126:
            guard buffer.count >= 4 else { return nil }
            payloadLength = Int(readUInt16(at: 2))
            headerLength = 4
        case 127:
            guard buffer.count >= 10 else { return nil }
            let longLength = readUInt64(at: 2)
            guard longLength & (1 << 63) == 0, let exact = Int(exactly: longLength) else {
                throw WebSocketCodecError.invalidPayloadLength
            }
            payloadLength = exact
            headerLength = 10
        default:
            payloadLength = shortLength
        }

        guard payloadLength <= maxMessageSize else { throw WebSocketCodecError.messageTooLarge }
        if opcode.isControl {
            guard isFinal else { throw WebSocketCodecError.fragmentedControlFrame }
            guard payloadLength <= 125 else { throw WebSocketCodecError.controlFrameTooLarge }
        }
        guard buffer.count >= headerLength + payloadLength else { return nil }

        let payloadRange = headerLength..<(headerLength + payloadLength)
        let payload = buffer.subdata(in: payloadRange)
        buffer.removeSubrange(0..<(headerLength + payloadLength))
        return Frame(isFinal: isFinal, opcode: opcode, payload: payload)
    }

    private mutating func consume(_ frame: Frame) throws -> WebSocketEvent? {
        switch frame.opcode {
        case .text, .binary:
            guard fragmentedOpcode == nil else { throw WebSocketCodecError.unexpectedDataFrame }
            if frame.isFinal {
                return event(opcode: frame.opcode, payload: frame.payload)
            }
            fragmentedOpcode = frame.opcode
            fragmentedPayload = frame.payload
            return nil
        case .continuation:
            guard let opcode = fragmentedOpcode else {
                throw WebSocketCodecError.unexpectedContinuation
            }
            guard fragmentedPayload.count + frame.payload.count <= maxMessageSize else {
                throw WebSocketCodecError.messageTooLarge
            }
            fragmentedPayload.append(frame.payload)
            guard frame.isFinal else { return nil }
            let payload = fragmentedPayload
            fragmentedOpcode = nil
            fragmentedPayload = Data()
            return event(opcode: opcode, payload: payload)
        case .ping:
            return .pongRequired(frame.payload)
        case .pong:
            return .pong(frame.payload)
        case .close:
            return .closed(frame.payload)
        }
    }

    private func event(opcode: WebSocketOpcode, payload: Data) -> WebSocketEvent {
        opcode == .text ? .text(payload) : .binary(payload)
    }

    private func readUInt16(at offset: Int) -> UInt16 {
        buffer[offset..<(offset + 2)].reduce(0) { ($0 << 8) | UInt16($1) }
    }

    private func readUInt64(at offset: Int) -> UInt64 {
        buffer[offset..<(offset + 8)].reduce(0) { ($0 << 8) | UInt64($1) }
    }

    private struct Frame {
        let isFinal: Bool
        let opcode: WebSocketOpcode
        let payload: Data
    }
}

private extension FixedWidthInteger {
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: bigEndian) { Array($0) }
    }
}

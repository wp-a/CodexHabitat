import Foundation
import Testing
@testable import CodexConnector

@Test
func decodesClientOrServerRequest() throws {
    let message = try JSONRPCCodec.decode(
        Data(#"{"id":1,"method":"initialize","params":{"client":"habitat"}}"#.utf8)
    )

    #expect(
        message == .request(
            id: .integer(1),
            method: "initialize",
            params: .object(["client": .string("habitat")])
        )
    )
}

@Test
func decodesSuccessfulResponse() throws {
    let message = try JSONRPCCodec.decode(Data(#"{"id":"one","result":{"ok":true}}"#.utf8))

    #expect(
        message == .response(
            id: .string("one"),
            result: .object(["ok": .bool(true)])
        )
    )
}

@Test
func decodesErrorResponse() throws {
    let message = try JSONRPCCodec.decode(
        Data(#"{"id":2,"error":{"code":-32001,"message":"Server overloaded; retry later."}}"#.utf8)
    )

    #expect(
        message == .error(
            id: .integer(2),
            error: JSONRPCError(code: -32_001, message: "Server overloaded; retry later.")
        )
    )
}

@Test
func decodesNotification() throws {
    let message = try JSONRPCCodec.decode(
        Data(#"{"method":"thread/status/changed","params":{"threadId":"thread-example"}}"#.utf8)
    )

    #expect(
        message == .notification(
            method: "thread/status/changed",
            params: .object(["threadId": .string("thread-example")])
        )
    )
}

@Test
func encodedNotificationRoundTrips() throws {
    let original = JSONRPCMessage.notification(
        method: "initialized",
        params: .object([:])
    )

    #expect(try JSONRPCCodec.decode(JSONRPCCodec.encode(original)) == original)
}

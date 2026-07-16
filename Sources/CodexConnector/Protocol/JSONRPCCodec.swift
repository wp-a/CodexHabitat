import Foundation

public enum JSONRPCCodecError: Error, Equatable {
    case rootIsNotObject
    case missingMethodOrResponse
    case invalidIdentifier
    case invalidError
}

public enum JSONRPCCodec {
    public static func decode(_ data: Data) throws -> JSONRPCMessage {
        let root = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case let .object(object) = root else {
            throw JSONRPCCodecError.rootIsNotObject
        }

        if case let .string(method)? = object["method"] {
            if let rawID = object["id"] {
                return .request(
                    id: try identifier(from: rawID),
                    method: method,
                    params: object["params"]
                )
            }
            return .notification(method: method, params: object["params"])
        }

        guard let rawID = object["id"] else {
            throw JSONRPCCodecError.missingMethodOrResponse
        }
        let id = try identifier(from: rawID)
        if let rawError = object["error"] {
            return .error(id: id, error: try rpcError(from: rawError))
        }
        if let result = object["result"] {
            return .response(id: id, result: result)
        }
        throw JSONRPCCodecError.missingMethodOrResponse
    }

    public static func encode(_ message: JSONRPCMessage) throws -> Data {
        let rootValue: JSONValue
        switch message {
        case let .request(id, method, params):
            rootValue = .object(compactObject(id: id, method: method, params: params))
        case let .response(id, result):
            rootValue = .object(["id": value(for: id), "result": result])
        case let .error(id, error):
            rootValue = .object([
                "id": value(for: id),
                "error": .object([
                    "code": .number(Double(error.code)),
                    "message": .string(error.message),
                ]),
            ])
        case let .notification(method, params):
            var object: [String: JSONValue] = ["method": .string(method)]
            object["params"] = params
            rootValue = .object(object)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(rootValue)
    }

    private static func compactObject(
        id: JSONRPCID,
        method: String,
        params: JSONValue?
    ) -> [String: JSONValue] {
        var object: [String: JSONValue] = [
            "id": value(for: id),
            "method": .string(method),
        ]
        object["params"] = params
        return object
    }

    private static func identifier(from value: JSONValue) throws -> JSONRPCID {
        switch value {
        case let .number(number):
            guard number.rounded() == number, let integer = Int(exactly: number) else {
                throw JSONRPCCodecError.invalidIdentifier
            }
            return .integer(integer)
        case let .string(string):
            return .string(string)
        case .null:
            return .null
        default:
            throw JSONRPCCodecError.invalidIdentifier
        }
    }

    private static func value(for id: JSONRPCID) -> JSONValue {
        switch id {
        case let .integer(value):
            .number(Double(value))
        case let .string(value):
            .string(value)
        case .null:
            .null
        }
    }

    private static func rpcError(from value: JSONValue) throws -> JSONRPCError {
        guard case let .object(object) = value,
              case let .number(rawCode)? = object["code"],
              rawCode.rounded() == rawCode,
              let code = Int(exactly: rawCode),
              case let .string(message)? = object["message"]
        else {
            throw JSONRPCCodecError.invalidError
        }
        return JSONRPCError(code: code, message: message)
    }
}

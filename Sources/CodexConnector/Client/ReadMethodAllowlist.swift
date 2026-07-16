public enum ReadMethodAllowlistError: Error, Equatable, Sendable {
    case methodNotAllowed(String)
    case unsafeParameters(String)
    case threadIsNotLoaded
}

enum ReadMethodAllowlist {
    static func validate(
        method: String,
        params: JSONValue?,
        loadedThreadIDs: Set<String>
    ) throws {
        switch method {
        case "thread/loaded/list":
            try requireObject(params, method: method, allowedKeys: ["cursor", "limit"])
        case "account/rateLimits/read":
            guard params == nil else {
                throw ReadMethodAllowlistError.unsafeParameters(method)
            }
        case "thread/read":
            let object = try requireLoadedThread(
                params,
                method: method,
                allowedKeys: ["threadId", "includeTurns"],
                loadedThreadIDs: loadedThreadIDs
            )
            guard object["includeTurns"] == .bool(false) else {
                throw ReadMethodAllowlistError.unsafeParameters(method)
            }
        case "thread/resume", "thread/unsubscribe":
            _ = try requireLoadedThread(
                params,
                method: method,
                allowedKeys: ["threadId"],
                loadedThreadIDs: loadedThreadIDs
            )
        default:
            throw ReadMethodAllowlistError.methodNotAllowed(method)
        }
    }

    @discardableResult
    private static func requireObject(
        _ params: JSONValue?,
        method: String,
        allowedKeys: Set<String>
    ) throws -> [String: JSONValue] {
        guard case let .object(object)? = params,
              Set(object.keys).isSubset(of: allowedKeys)
        else {
            throw ReadMethodAllowlistError.unsafeParameters(method)
        }
        return object
    }

    private static func requireLoadedThread(
        _ params: JSONValue?,
        method: String,
        allowedKeys: Set<String>,
        loadedThreadIDs: Set<String>
    ) throws -> [String: JSONValue] {
        let object = try requireObject(params, method: method, allowedKeys: allowedKeys)
        guard case let .string(threadID)? = object["threadId"],
              loadedThreadIDs.contains(threadID)
        else {
            throw ReadMethodAllowlistError.threadIsNotLoaded
        }
        return object
    }
}

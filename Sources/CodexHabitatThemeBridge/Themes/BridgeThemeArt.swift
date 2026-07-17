import Foundation

enum BridgeThemeArt {
    static let maximumBytes = 1024 * 1024

    static func dataURL(data: Data, pathExtension: String) -> String? {
        guard data.count <= maximumBytes,
              let mime = mimeType(data: data, pathExtension: pathExtension)
        else {
            return nil
        }
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }

    static func isValidDataURL(_ value: String) -> Bool {
        guard value.count <= 1_400_100,
              let separator = value.firstIndex(of: ",")
        else {
            return false
        }
        let prefix = String(value[..<separator])
        let expectedExtension: String
        switch prefix {
        case "data:image/png;base64": expectedExtension = "png"
        case "data:image/jpeg;base64": expectedExtension = "jpg"
        case "data:image/webp;base64": expectedExtension = "webp"
        default: return false
        }
        guard let data = Data(base64Encoded: String(value[value.index(after: separator)...])),
              data.count <= maximumBytes
        else {
            return false
        }
        return mimeType(data: data, pathExtension: expectedExtension) != nil
    }

    static func mimeType(data: Data, pathExtension: String) -> String? {
        switch pathExtension.lowercased() {
        case "png" where data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]):
            return "image/png"
        case "jpg" where data.starts(with: [0xFF, 0xD8, 0xFF]),
             "jpeg" where data.starts(with: [0xFF, 0xD8, 0xFF]):
            return "image/jpeg"
        case "webp" where data.count >= 12
            && data.starts(with: Array("RIFF".utf8))
            && Data(data[8..<12]) == Data("WEBP".utf8):
            return "image/webp"
        default:
            return nil
        }
    }
}

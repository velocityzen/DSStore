import DSStore
import Foundation

struct TableRow {
    let filename: String
    let code: String
    let meaning: String
    let valueLines: [String]
}

struct JSONEntry: Encodable {
    let filename: String
    let code: String
    let meaning: String
    let valueDescription: String
    let value: JSONValue
}

enum JSONValue: Encodable {
    case long(UInt32)
    case short(UInt32)
    case bool(Bool)
    case blob(String)
    case type(String)
    case unicodeString(String)
    case comp(UInt64)
    case dutc(UInt64)

    init(_ value: DSStoreValue) {
        switch value {
        case .long(let number):
            self = .long(number)
        case .short(let number):
            self = .short(number)
        case .bool(let flag):
            self = .bool(flag)
        case .blob(let data):
            self = .blob(data.map { String(format: "%02x", $0) }.joined())
        case .type(let code):
            self = .type(code)
        case .unicodeString(let string):
            self = .unicodeString(string)
        case .comp(let number):
            self = .comp(number)
        case .dutc(let number):
            self = .dutc(number)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .long(let number):
            try container.encode("long", forKey: .type)
            try container.encode(number, forKey: .number)
        case .short(let number):
            try container.encode("short", forKey: .type)
            try container.encode(number, forKey: .number)
        case .bool(let flag):
            try container.encode("bool", forKey: .type)
            try container.encode(flag, forKey: .bool)
        case .blob(let value):
            try container.encode("blob", forKey: .type)
            try container.encode(value, forKey: .string)
        case .type(let code):
            try container.encode("type", forKey: .type)
            try container.encode(code, forKey: .string)
        case .unicodeString(let string):
            try container.encode("unicodeString", forKey: .type)
            try container.encode(string, forKey: .string)
        case .comp(let number):
            try container.encode("comp", forKey: .type)
            try container.encode(number, forKey: .number64)
        case .dutc(let number):
            try container.encode("dutc", forKey: .type)
            try container.encode(number, forKey: .number64)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case number
        case number64
        case bool
        case string
    }
}

enum ANSIColor: String {
    case cyan = "\u{001B}[36m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case magenta = "\u{001B}[35m"

    func wrap(_ value: String) -> String {
        "\(rawValue)\(value)\u{001B}[0m"
    }
}

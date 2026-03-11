import FP
import Foundation

/// A typed payload stored in a `.DS_Store` record.
public enum DSStoreValue: Equatable, Sendable {
    /// A 32-bit unsigned integer stored as a Finder `long`.
    case long(UInt32)
    /// A 32-bit unsigned integer stored as a Finder `shor`.
    case short(UInt32)
    /// A Boolean stored as a Finder `bool`.
    case bool(Bool)
    /// An arbitrary binary blob stored as a Finder `blob`.
    case blob(Data)
    /// A four-character code stored as a Finder `type`.
    case type(String)
    /// A UTF-16 string stored as a Finder `ustr`.
    case unicodeString(String)
    /// A 64-bit unsigned integer stored as a Finder `comp`.
    case comp(UInt64)
    /// A 64-bit unsigned integer stored as a Finder `dutc`.
    case dutc(UInt64)

    var dataTypeCode: String {
        switch self {
        case .long:
            "long"
        case .short:
            "shor"
        case .bool:
            "bool"
        case .blob:
            "blob"
        case .type:
            "type"
        case .unicodeString:
            "ustr"
        case .comp:
            "comp"
        case .dutc:
            "dutc"
        }
    }

    var byteSize: Int {
        switch self {
        case .long, .short, .type:
            4
        case .bool:
            1
        case .blob(let data):
            4 + data.count
        case .unicodeString(let value):
            4 + value.utf16.count * 2
        case .comp, .dutc:
            8
        }
    }

    static func read(dataTypeCode: String, from reader: inout BinaryReader) -> Result<
        Self, DSStoreError
    > {
        switch dataTypeCode {
        case "bool":
            return reader.readUInt8().map { .bool($0 != 0) }
        case "long":
            return reader.readUInt32().map(Self.long)
        case "shor":
            return reader.readUInt32().map(Self.short)
        case "blob":
            return reader.readUInt32().flatMap { blobLength in
                reader.readData(count: Int(blobLength)).map(Self.blob)
            }
        case "ustr":
            return reader.readUInt32().flatMap { stringLength in
                reader.readUTF16BE(codeUnitCount: Int(stringLength)).map(Self.unicodeString)
            }
        case "type":
            return reader.readFourCharacterCode().map(Self.type)
        case "comp":
            return reader.readUInt64().map(Self.comp)
        case "dutc":
            return reader.readUInt64().map(Self.dutc)
        default:
            return .failure(.invalidDataType(dataTypeCode))
        }
    }

    func write(to writer: inout BinaryWriter) -> Result<Void, DSStoreError> {
        switch self {
        case .long(let value), .short(let value):
            writer.writeUInt32(value)
            return .success(())
        case .bool(let value):
            writer.writeUInt8(value ? 1 : 0)
            return .success(())
        case .blob(let data):
            writer.writeUInt32(UInt32(data.count))
            writer.writeData(data)
            return .success(())
        case .type(let value):
            return writer.writeFourCharacterCode(value)
        case .unicodeString(let value):
            writer.writeUInt32(UInt32(value.utf16.count))
            writer.writeUTF16BE(value)
            return .success(())
        case .comp(let value), .dutc(let value):
            writer.writeUInt64(value)
            return .success(())
        }
    }
}

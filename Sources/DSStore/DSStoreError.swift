import Foundation

/// Typed failures produced while decoding, encoding, or editing `.DS_Store` files.
public enum DSStoreError: Error, Equatable, LocalizedError {
    case invalidFileHeader
    case invalidMagic
    case inconsistentRootOffsets
    case invalidOffsetTable
    case invalidBlockIdentifier(Int)
    case invalidBlockRange
    case invalidRootBlock
    case invalidBTreeNode
    case invalidRecordType(String)
    case invalidDataType(String)
    case invalidUTF16String
    case invalidFourCharacterCode(String)
    case invalidPropertyList
    case invalidPropertyListObject
    case propertyListEncodingFailed
    case unsupportedWriteValue(String)
    case ioError(String)

    /// A human-readable description suitable for logs and CLI output.
    public var errorDescription: String? {
        switch self {
        case .invalidFileHeader:
            "The DS_Store file header is invalid."
        case .invalidMagic:
            "The DS_Store file does not start with the expected Bud1 magic."
        case .inconsistentRootOffsets:
            "The DS_Store file contains inconsistent root block offsets."
        case .invalidOffsetTable:
            "The DS_Store allocator metadata contains an invalid offset table."
        case .invalidBlockIdentifier(let identifier):
            "The DS_Store block identifier \(identifier) is not allocated."
        case .invalidBlockRange:
            "The DS_Store block range is outside the file."
        case .invalidRootBlock:
            "The DS_Store root block metadata is invalid."
        case .invalidBTreeNode:
            "The DS_Store B-tree node is malformed."
        case .invalidRecordType(let value):
            "The DS_Store record type '\(value)' is invalid."
        case .invalidDataType(let value):
            "The DS_Store data type '\(value)' is invalid."
        case .invalidUTF16String:
            "The DS_Store file contains invalid UTF-16 data."
        case .invalidFourCharacterCode(let value):
            "'\(value)' must be exactly four bytes."
        case .invalidPropertyList:
            "The DS_Store property list blob is invalid."
        case .invalidPropertyListObject:
            "The DS_Store property list object has an unexpected shape."
        case .propertyListEncodingFailed:
            "The DS_Store property list could not be encoded."
        case .unsupportedWriteValue(let value):
            "The DS_Store value '\(value)' cannot be written."
        case .ioError(let message):
            message
        }
    }
}

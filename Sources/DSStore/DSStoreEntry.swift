import FP
import Foundation

/// A single Finder metadata record in a `.DS_Store` file.
public struct DSStoreEntry: Equatable, Sendable {
    /// The Finder filename the record applies to.
    public let filename: String
    /// The four-character Finder record code, such as `Iloc` or `bwsp`.
    public let structureID: String
    /// The typed payload stored for the record.
    public let value: DSStoreValue

    /// Creates a validated entry.
    ///
    /// - Parameters:
    ///   - filename: The Finder filename the record applies to.
    ///   - structureID: The four-character record code.
    ///   - value: The typed record payload.
    /// - Returns: A typed result containing the entry or a validation error.
    public static func make(filename: String, structureID: String, value: DSStoreValue) -> Result<
        Self, DSStoreError
    > {
        guard structureID.utf8.count == 4 else {
            return .failure(.invalidFourCharacterCode(structureID))
        }

        return .success(
            Self(filename: filename, structureID: structureID, value: value, bypassValidation: ()))
    }

    init(filename: String, structureID: String, value: DSStoreValue, bypassValidation _: Void) {
        self.filename = filename
        self.structureID = structureID
        self.value = value
    }

    var byteSize: Int {
        4 + filename.utf16.count * 2 + 4 + 4 + value.byteSize
    }

    static func read(from reader: inout BinaryReader) -> Result<Self, DSStoreError> {
        Result<Self, DSStoreError>.Do
            .bind { reader.readUInt32() }
            .bind { filenameLength in reader.readUTF16BE(codeUnitCount: Int(filenameLength)) }
            .bind { _, _ in reader.readFourCharacterCode() }
            .bind { _, _, _ in reader.readFourCharacterCode() }
            .bind { _, _, _, dataTypeCode in
                DSStoreValue.read(dataTypeCode: dataTypeCode, from: &reader)
            }
            .map { _, filename, structureID, _, value in
                Self(
                    filename: filename, structureID: structureID, value: value, bypassValidation: ()
                )
            }
    }

    func write(to writer: inout BinaryWriter) -> Result<Void, DSStoreError> {
        writer.writeUInt32(UInt32(filename.utf16.count))
        writer.writeUTF16BE(filename)
        return writer.writeFourCharacterCode(structureID)
            .flatMap { writer.writeFourCharacterCode(value.dataTypeCode) }
            .flatMap { value.write(to: &writer) }
    }
}

extension DSStoreEntry: Comparable {
    /// Orders entries the way Finder stores them: case-insensitive filename, then structure ID.
    public static func < (lhs: DSStoreEntry, rhs: DSStoreEntry) -> Bool {
        let lhsName = lhs.filename.lowercased()
        let rhsName = rhs.filename.lowercased()

        if lhsName != rhsName {
            return lhsName < rhsName
        }

        return lhs.structureID < rhs.structureID
    }
}

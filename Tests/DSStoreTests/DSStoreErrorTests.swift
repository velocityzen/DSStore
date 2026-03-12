import Foundation
import Testing

@testable import DSStore

@Suite("DSStore error paths")
struct DSStoreErrorTests {

    // MARK: - File header validation

    @Test("rejects empty data")
    func rejectsEmptyData() {
        let result = DSStoreFile.read(from: Data())
        #expect(result == .failure(.invalidFileHeader))
    }

    @Test("rejects data shorter than the file header")
    func rejectsTruncatedHeader() {
        let result = DSStoreFile.read(from: Data(repeating: 0, count: 10))
        #expect(result == .failure(.invalidFileHeader))
    }

    @Test("rejects file with wrong magic number")
    func rejectsWrongMagic() {
        var data = Data(repeating: 0, count: 64)
        // magic1 should be 1
        data[0] = 0
        data[1] = 0
        data[2] = 0
        data[3] = 2
        // magic should be "Bud1" but we write "XXXX"
        data[4] = 0x58
        data[5] = 0x58
        data[6] = 0x58
        data[7] = 0x58
        let result = DSStoreFile.read(from: data)
        #expect(result == .failure(.invalidMagic))
    }

    @Test("rejects file with inconsistent root offsets")
    func rejectsInconsistentRootOffsets() {
        var data = Data(repeating: 0, count: 64)
        // magic1 = 1
        data[3] = 1
        // magic = "Bud1"
        data[4] = 0x42
        data[5] = 0x75
        data[6] = 0x64
        data[7] = 0x31
        // offset = 100
        data[11] = 100
        // size = 0
        // offset2 = 200 (different from offset)
        data[19] = 200
        let result = DSStoreFile.read(from: data)
        #expect(result == .failure(.inconsistentRootOffsets))
    }

    // MARK: - Entry validation

    @Test("rejects structure ID that is not four characters")
    func rejectsInvalidStructureID() {
        let result = DSStoreEntry.make(filename: "test", structureID: "AB", value: .long(0))
        #expect(result == .failure(.invalidFourCharacterCode("AB")))
    }

    @Test("rejects empty structure ID")
    func rejectsEmptyStructureID() {
        let result = DSStoreEntry.make(filename: "test", structureID: "", value: .long(0))
        #expect(result == .failure(.invalidFourCharacterCode("")))
    }

    @Test("rejects five-character structure ID")
    func rejectsTooLongStructureID() {
        let result = DSStoreEntry.make(filename: "test", structureID: "ABCDE", value: .long(0))
        #expect(result == .failure(.invalidFourCharacterCode("ABCDE")))
    }

    // MARK: - Data type validation

    @Test("rejects unknown data type code")
    func rejectsUnknownDataType() {
        // Build a minimal binary entry with an unknown data type
        var writer = BinaryWriter()
        writer.writeUInt32(4)  // filename length
        writer.writeUTF16BE("test")
        _ = writer.writeFourCharacterCode("Iloc")
        _ = writer.writeFourCharacterCode("zzzz")  // unknown data type
        writer.writeUInt32(0)  // dummy payload

        var reader = BinaryReader(data: writer.data)
        let result = DSStoreEntry.read(from: &reader)
        guard case .failure(.invalidDataType("zzzz")) = result else {
            Issue.record("Expected invalidDataType error, got \(result)")
            return
        }
    }

    // MARK: - BinaryReader bounds checking

    @Test("readUInt32 fails on insufficient data")
    func readUInt32FailsOnShortData() {
        var reader = BinaryReader(data: Data([0x01, 0x02]))
        let result = reader.readUInt32()
        #expect(result == .failure(.invalidBlockRange))
    }

    @Test("readUInt64 fails on insufficient data")
    func readUInt64FailsOnShortData() {
        var reader = BinaryReader(data: Data([0x01, 0x02, 0x03, 0x04]))
        let result = reader.readUInt64()
        #expect(result == .failure(.invalidBlockRange))
    }

    @Test("readData fails when requesting more bytes than available")
    func readDataFailsOverflow() {
        var reader = BinaryReader(data: Data([0x01]))
        let result = reader.readData(count: 10)
        #expect(result == .failure(.invalidBlockRange))
    }

    @Test("readUTF16BE fails on invalid data")
    func readUTF16BEFailsOnBadData() {
        // Lone high surrogate with no pair
        var reader = BinaryReader(data: Data([0xD8, 0x00]))
        let result = reader.readUTF16BE(codeUnitCount: 1)
        #expect(result == .failure(.invalidUTF16String))
    }

    // MARK: - Window frame validation

    @Test("rejects window frame with invalid view code")
    func rejectsInvalidWindowFrameView() {
        let result = DSStoreWindowFrame.make(x: 0, y: 0, width: 100, height: 100, view: "ab")
        #expect(result == .failure(.invalidFourCharacterCode("ab")))
    }

    // MARK: - Color parsing

    @Test("rejects color without hash prefix")
    func rejectsColorWithoutHash() {
        let result = DSStoreBackground.color(hex: "ff0000")
        guard case .failure(.unsupportedWriteValue) = result else {
            Issue.record("Expected unsupportedWriteValue error, got \(result)")
            return
        }
    }

    @Test("rejects color with invalid length")
    func rejectsColorInvalidLength() {
        let result = DSStoreBackground.color(hex: "#abcd")
        guard case .failure(.unsupportedWriteValue) = result else {
            Issue.record("Expected unsupportedWriteValue error, got \(result)")
            return
        }
    }

    @Test("rejects color with non-hex characters")
    func rejectsColorNonHex() {
        let result = DSStoreBackground.color(hex: "#gggggg")
        guard case .failure(.unsupportedWriteValue) = result else {
            Issue.record("Expected unsupportedWriteValue error, got \(result)")
            return
        }
    }

    // MARK: - DSStoreWindowUpdate convenience

    @Test("settingWindowSettings fails without width/height when no existing frame")
    func failsWithoutRequiredDimensions() {
        let store = DSStoreFile()
        let result = store.withWindowSettings(DSStoreWindowUpdate(x: 50))
        guard case .failure(.unsupportedWriteValue) = result else {
            Issue.record("Expected unsupportedWriteValue error, got \(result)")
            return
        }
    }

    // MARK: - Empty and single-entry files

    @Test("round trips an empty store")
    func roundTripsEmptyStore() throws {
        let store = DSStoreFile()
        let encoded = try store.data().get()
        let decoded = try DSStoreFile.read(from: encoded).get()

        #expect(decoded.entries.isEmpty)
    }

    @Test("round trips a single-entry store")
    func roundTripsSingleEntry() throws {
        let entry = try DSStoreEntry.make(
            filename: "test", structureID: "cmmt", value: .unicodeString("hello")
        ).get()
        let store = DSStoreFile(entries: [entry])
        let encoded = try store.data().get()
        let decoded = try DSStoreFile.read(from: encoded).get()

        #expect(decoded.entries == [entry])
    }

    // MARK: - Block range errors

    @Test("rejects block read outside file bounds")
    func rejectsBlockOutsideBounds() throws {
        let store = DSStoreFile()
        let encoded = try store.data().get()
        // Corrupt both root offsets (they must match) to point past the file
        var corrupted = encoded
        corrupted[8] = 0xFF
        corrupted[9] = 0xFF
        corrupted[10] = 0xFF
        corrupted[11] = 0xFF
        // size at bytes 12-15, then offset2 at bytes 16-19 must match offset
        corrupted[16] = 0xFF
        corrupted[17] = 0xFF
        corrupted[18] = 0xFF
        corrupted[19] = 0xFF
        let result = DSStoreFile.read(from: corrupted)
        #expect(result == .failure(.invalidBlockRange))
    }

    // MARK: - FourCharacterCode in BinaryWriter

    @Test("writeFourCharacterCode rejects invalid length")
    func writerRejectsInvalidFCC() {
        var writer = BinaryWriter()
        let result = writer.writeFourCharacterCode("AB")
        guard case .failure(.invalidFourCharacterCode("AB")) = result else {
            Issue.record("Expected invalidFourCharacterCode error, got \(result)")
            return
        }
    }

    // MARK: - Data extension edge cases

    @Test("Data safe subscript returns nil for out of bounds")
    func dataSafeSubscriptOOB() {
        let data = Data([0x01, 0x02])
        #expect(data[safe: 5] == nil)
        #expect(data[safe: -1] == nil)
        #expect(data[safe: 0] == 0x01)
    }

    @Test("Data uint16 returns nil for negative offset")
    func dataUint16NegativeOffset() {
        let data = Data([0x00, 0x01, 0x00, 0x02])
        #expect(data.uint16(at: -1) == nil)
        #expect(data.uint16(at: 0) == 0x0001)
    }

    @Test("Data uint32 returns nil for offset past end")
    func dataUint32PastEnd() {
        let data = Data([0x00, 0x01])
        #expect(data.uint32(at: 0) == nil)
    }

    @Test("Data fourCharacterCode returns nil for short data")
    func dataFCCShortData() {
        let data = Data([0x41, 0x42])
        #expect(data.fourCharacterCode(at: 0) == nil)
    }
}

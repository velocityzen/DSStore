import Foundation

struct BinaryReader {
    private let data: Data
    private(set) var position: Int = 0

    init(data: Data) {
        self.data = data
    }

    var remainingCount: Int {
        data.count - position
    }

    mutating func readUInt8() -> Result<UInt8, DSStoreError> {
        readData(count: 1).map { bytes in
            bytes[bytes.startIndex]
        }
    }

    mutating func readUInt32() -> Result<UInt32, DSStoreError> {
        readData(count: 4).map { bytes in
            bytes.withUnsafeBytes { rawBuffer in
                UInt32(bigEndian: rawBuffer.load(as: UInt32.self))
            }
        }
    }

    mutating func readUInt64() -> Result<UInt64, DSStoreError> {
        readData(count: 8).map { bytes in
            bytes.withUnsafeBytes { rawBuffer in
                UInt64(bigEndian: rawBuffer.load(as: UInt64.self))
            }
        }
    }

    mutating func readData(count: Int) -> Result<Data, DSStoreError> {
        guard count >= 0, position + count <= data.count else {
            return .failure(.invalidBlockRange)
        }

        let range = position..<position + count
        position += count
        return .success(data.subdata(in: range))
    }

    mutating func readFourCharacterCode() -> Result<String, DSStoreError> {
        readData(count: 4).map { raw in
            String(decoding: raw, as: UTF8.self)
        }
    }

    mutating func readUTF16BE(codeUnitCount: Int) -> Result<String, DSStoreError> {
        let raw = readData(count: codeUnitCount * 2)
        return raw.flatMap { raw in
            guard let string = String(data: raw, encoding: .utf16BigEndian) else {
                return .failure(.invalidUTF16String)
            }
            return .success(string)
        }
    }
}

struct BinaryWriter {
    private(set) var data: Data = .init()

    mutating func writeUInt8(_ value: UInt8) {
        data.append(value)
    }

    mutating func writeUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }

    mutating func writeUInt64(_ value: UInt64) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }

    mutating func writeData(_ value: Data) {
        data.append(value)
    }

    mutating func writeBytes(_ value: [UInt8]) {
        data.append(contentsOf: value)
    }

    mutating func writeFourCharacterCode(_ value: String) -> Result<Void, DSStoreError> {
        guard value.utf8.count == 4 else {
            return .failure(.invalidFourCharacterCode(value))
        }

        data.append(contentsOf: value.utf8)
        return .success(())
    }

    mutating func writeUTF16BE(_ value: String) {
        let utf16 = value.utf16.map(\.bigEndian)
        utf16.withUnsafeBufferPointer { buffer in
            data.append(
                UnsafeBufferPointer(
                    start: UnsafeRawPointer(buffer.baseAddress)?.assumingMemoryBound(
                        to: UInt8.self), count: buffer.count * 2))
        }
    }

    mutating func padZeroes(toCount count: Int) {
        guard data.count < count else { return }
        data.append(contentsOf: repeatElement(0, count: count - data.count))
    }
}

import Foundation

extension Data {
    subscript(safe index: Int) -> UInt8? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }

    func uint16(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else { return nil }
        return subdata(in: offset..<offset + 2).withUnsafeBytes { rawBuffer in
            UInt16(bigEndian: rawBuffer.load(as: UInt16.self))
        }
    }

    func uint32(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        return subdata(in: offset..<offset + 4).withUnsafeBytes { rawBuffer in
            UInt32(bigEndian: rawBuffer.load(as: UInt32.self))
        }
    }

    func uint64(at offset: Int) -> UInt64? {
        guard offset >= 0, offset + 8 <= count else { return nil }
        return subdata(in: offset..<offset + 8).withUnsafeBytes { rawBuffer in
            UInt64(bigEndian: rawBuffer.load(as: UInt64.self))
        }
    }

    func littleEndianDouble(at offset: Int) -> Double? {
        guard offset >= 0, offset + 8 <= count else { return nil }
        return subdata(in: offset..<offset + 8).withUnsafeBytes { rawBuffer in
            let bits = UInt64(littleEndian: rawBuffer.load(as: UInt64.self))
            return Double(bitPattern: bits)
        }
    }

    func fourCharacterCode(at offset: Int) -> String? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        return String(decoding: subdata(in: offset..<offset + 4), as: UTF8.self)
    }
}

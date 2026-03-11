import FP
import Foundation

final class DSStoreBuddyAllocator {
    private static let minimumWidth = 5
    private static let freeListCount = 32
    private static let offsetTableAlignment = 256
    private static let encodedWidthMask: UInt32 = 0x1F
    private static let fileHeaderSize = 0x20
    private static let defaultUnknown2 = Data([
        0x00, 0x00, 0x10, 0x0C, 0x00, 0x00, 0x00, 0x87, 0x00, 0x00, 0x20, 0x0B, 0x00, 0x00, 0x00,
        0x00,
    ])

    private(set) var fileData: Data
    private var unknown2: Data
    private var unknown3: UInt32
    private(set) var offsets: [UInt32?]
    var tableOfContents: [String: UInt32]
    private var freeLists: [[UInt32]]
    private let fileOffsetFudge = 4

    init() {
        fileData = Data(repeating: 0, count: 4 + Self.fileHeaderSize)
        unknown2 = Self.defaultUnknown2
        unknown3 = 0
        offsets = []
        tableOfContents = [:]
        freeLists = Array(repeating: [], count: Self.freeListCount)
        freeLists[31] = [0]
        _ = allocate(size: 32, preferredBlockNumber: 0)
    }

    private init(
        fileData: Data,
        unknown2: Data,
        unknown3: UInt32,
        offsets: [UInt32?],
        tableOfContents: [String: UInt32],
        freeLists: [[UInt32]]
    ) {
        self.fileData = fileData
        self.unknown2 = unknown2
        self.unknown3 = unknown3
        self.offsets = offsets
        self.tableOfContents = tableOfContents
        self.freeLists = freeLists
    }

    static func open(data: Data) -> Result<DSStoreBuddyAllocator, DSStoreError> {
        guard data.count >= 4 + fileHeaderSize else {
            return .failure(.invalidFileHeader)
        }

        var reader = BinaryReader(data: data)
        return Result<DSStoreBuddyAllocator, DSStoreError>.Do
            .bind { reader.readUInt32() }
            .bind { _ in reader.readFourCharacterCode() }
            .bind { _, _ in reader.readUInt32() }
            .bind { _, _, _ in reader.readUInt32() }
            .bind { _, _, _, _ in reader.readUInt32() }
            .bind { _, _, _, _, _ in reader.readData(count: 16) }
            .flatMap { magic1, magic, offset, size, offset2, unknown2 in
                guard magic1 == 1, magic == "Bud1" else {
                    return .failure(.invalidMagic)
                }

                guard offset == offset2 else {
                    return .failure(.inconsistentRootOffsets)
                }

                return readBlock(from: data, offset: Int(offset), length: Int(size))
                    .flatMap { rootBlock in
                        parseRootBlock(rootBlock, fileData: data, unknown2: unknown2)
                    }
            }
    }

    func blockData(number: Int) -> Result<Data, DSStoreError> {
        blockOffset(number: number).flatMap { offset, size in
            Self.readBlock(from: fileData, offset: Int(offset), length: size)
        }
    }

    func writeBlock(number: Int, data: Data, zeroFillTo blockSize: Int? = nil) -> Result<
        Void, DSStoreError
    > {
        blockOffset(number: number).flatMap { offset, size in
            let targetSize = blockSize ?? size
            guard data.count <= targetSize else {
                return .failure(.invalidBlockRange)
            }

            ensureFileLength(fileOffsetFudge + Int(offset) + targetSize)
            let start = fileOffsetFudge + Int(offset)
            fileData.replaceSubrange(start..<start + data.count, with: data)

            if data.count < targetSize {
                let zeroes = Data(repeating: 0, count: targetSize - data.count)
                fileData.replaceSubrange(start + data.count..<start + targetSize, with: zeroes)
            }

            return .success(())
        }
    }

    func allocate(size: Int, preferredBlockNumber: Int? = nil) -> Result<Int, DSStoreError> {
        let blockNumber = preferredBlockNumber ?? nextAvailableBlockNumber()
        let width = requiredWidth(for: size)

        if blockNumber < offsets.count, let current = offsets[blockNumber] {
            let currentWidth = Int(current & Self.encodedWidthMask)
            if currentWidth == width {
                return .success(blockNumber)
            }

            freeBlock(number: blockNumber)
        }

        return allocateOffset(width: width).map { offset in
            let encoded = offset | UInt32(width)
            while offsets.count <= blockNumber {
                offsets.append(nil)
            }
            offsets[blockNumber] = encoded

            let blockLength = 1 << width
            ensureFileLength(fileOffsetFudge + Int(offset) + blockLength)
            return blockNumber
        }
    }

    func freeBlock(number: Int) {
        guard number < offsets.count, let encoded = offsets[number] else {
            return
        }

        let width = Int(encoded & Self.encodedWidthMask)
        let offset = encoded & ~Self.encodedWidthMask
        mergeFree(offset: offset, width: width)
        offsets[number] = nil
    }

    func writeMetadata() -> Result<Data, DSStoreError> {
        if offsets.isEmpty {
            offsets.append(nil)
        }

        let rootBlockSize = metadataRootBlockSize()
        return allocate(size: rootBlockSize, preferredBlockNumber: 0)
            .flatMap { _ in makeRootBlockData() }
            .flatMap { rootMetadata in
                writeBlock(number: 0, data: rootMetadata).flatMap {
                    blockOffset(number: 0).flatMap { rootOffset, rootSize in
                        var writer = BinaryWriter()
                        writer.writeUInt32(1)
                        return writer.writeFourCharacterCode("Bud1").map {
                            writer.writeUInt32(rootOffset)
                            writer.writeUInt32(UInt32(rootSize))
                            writer.writeUInt32(rootOffset)
                            writer.writeData(unknown2)
                            fileData.replaceSubrange(0..<writer.data.count, with: writer.data)
                            return fileData
                        }
                    }
                }
            }
    }

    private static func parseRootBlock(
        _ rootBlock: Data,
        fileData: Data,
        unknown2: Data
    ) -> Result<DSStoreBuddyAllocator, DSStoreError> {
        var rootReader = BinaryReader(data: rootBlock)
        return Result<DSStoreBuddyAllocator, DSStoreError>.Do
            .bind { rootReader.readUInt32() }
            .bind { _ in rootReader.readUInt32() }
            .bind { offsetCountValue, _ in
                let offsetCount = Int(offsetCountValue)
                let offsetSlots = ((offsetCount + offsetTableAlignment - 1) / offsetTableAlignment) * offsetTableAlignment
                return Array(0..<offsetSlots).traverse { index in
                    rootReader.readUInt32().map { entry in
                        index < offsetCount ? (entry == 0 ? nil : entry) : nil
                    }
                }
            }
            .bind { _, _, _ in rootReader.readUInt32() }
            .bind { _, _, _, tocCountValue in
                Array(0..<Int(tocCountValue)).traverse { _ in
                    Result<(String, UInt32), DSStoreError>.Do
                        .bind { rootReader.readUInt8() }
                        .bind { nameLength in rootReader.readData(count: Int(nameLength)) }
                        .bind { _, _ in rootReader.readUInt32() }
                        .map { _, nameData, value in
                            (String(decoding: nameData, as: UTF8.self), value)
                        }
                }
            }
            .bind { _, _, _, _, _ in
                Array(0..<freeListCount).traverse { _ in
                    rootReader.readUInt32().flatMap { blockCountValue in
                        Array(0..<Int(blockCountValue)).traverse { _ in
                            rootReader.readUInt32()
                        }
                    }
                }
            }
            .map { offsetCountValue, unknown3, paddedOffsets, _, tocPairs, freeLists in
                DSStoreBuddyAllocator(
                    fileData: fileData,
                    unknown2: unknown2,
                    unknown3: unknown3,
                    offsets: Array(paddedOffsets.prefix(Int(offsetCountValue))),
                    tableOfContents: Dictionary(uniqueKeysWithValues: tocPairs),
                    freeLists: freeLists
                )
            }
    }

    private func nextAvailableBlockNumber() -> Int {
        for index in 1..<offsets.count where offsets[index] == nil {
            return index
        }

        return max(1, offsets.count)
    }

    private func requiredWidth(for size: Int) -> Int {
        var width = Self.minimumWidth
        while size > (1 << width) {
            width += 1
        }
        return width
    }

    private func allocateOffset(width: Int) -> Result<UInt32, DSStoreError> {
        if let first = freeLists[width].first {
            freeLists[width].removeFirst()
            return .success(first)
        }

        guard width + 1 < freeLists.count else {
            return .failure(.invalidOffsetTable)
        }

        return allocateOffset(width: width + 1).map { offset in
            let buddy = offset ^ UInt32(1 << width)
            mergeFree(offset: buddy, width: width)
            return offset
        }
    }

    private func mergeFree(offset: UInt32, width: Int) {
        let buddy = offset ^ UInt32(1 << width)
        if let index = freeLists[width].firstIndex(of: buddy) {
            freeLists[width].remove(at: index)
            mergeFree(offset: min(offset, buddy), width: width + 1)
            return
        }

        freeLists[width].append(offset)
        freeLists[width].sort()
    }

    private func metadataRootBlockSize() -> Int {
        let offsetCount = offsets.count
        let paddedOffsetCount = offsetCount == 0 ? 0 : ((offsetCount + Self.offsetTableAlignment - 1) / Self.offsetTableAlignment) * Self.offsetTableAlignment
        let tocSize = tableOfContents.keys.reduce(4) { partialResult, key in
            partialResult + 5 + key.utf8.count
        }
        let freeListSize = freeLists.reduce(0) { partialResult, list in
            partialResult + 4 + list.count * 4
        }
        return 8 + paddedOffsetCount * 4 + tocSize + freeListSize
    }

    private func makeRootBlockData() -> Result<Data, DSStoreError> {
        var writer = BinaryWriter()
        writer.writeUInt32(UInt32(offsets.count))
        writer.writeUInt32(unknown3)

        let paddedOffsetCount = offsets.isEmpty ? 0 : ((offsets.count + Self.offsetTableAlignment - 1) / Self.offsetTableAlignment) * Self.offsetTableAlignment
        for index in 0..<paddedOffsetCount {
            let value = index < offsets.count ? offsets[index] ?? 0 : 0
            writer.writeUInt32(value)
        }

        let keys = tableOfContents.keys.sorted()
        writer.writeUInt32(UInt32(keys.count))
        for key in keys {
            let utf8 = Array(key.utf8)
            writer.writeUInt8(UInt8(utf8.count))
            writer.writeBytes(utf8)
            writer.writeUInt32(tableOfContents[key] ?? 0)
        }

        for list in freeLists {
            writer.writeUInt32(UInt32(list.count))
            for offset in list {
                writer.writeUInt32(offset)
            }
        }

        return .success(writer.data)
    }

    private func blockOffset(number: Int) -> Result<(UInt32, Int), DSStoreError> {
        guard number < offsets.count, let encoded = offsets[number] else {
            return .failure(.invalidBlockIdentifier(number))
        }

        let offset = encoded & ~Self.encodedWidthMask
        let length = 1 << Int(encoded & Self.encodedWidthMask)
        return .success((offset, length))
    }

    private func ensureFileLength(_ count: Int) {
        guard fileData.count < count else { return }
        fileData.append(contentsOf: repeatElement(0, count: count - fileData.count))
    }

    private static func readBlock(from data: Data, offset: Int, length: Int) -> Result<
        Data, DSStoreError
    > {
        let start = 4 + offset
        let end = start + length
        guard offset >= 0, length >= 0, end <= data.count else {
            return .failure(.invalidBlockRange)
        }

        return .success(data.subdata(in: start..<end))
    }
}

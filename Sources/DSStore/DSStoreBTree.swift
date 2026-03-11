import FP
import Foundation

enum DSStoreBTree {
    private static let defaultPageSize = 0x1000

    static func readEntries(from allocator: DSStoreBuddyAllocator) -> Result<
        [DSStoreEntry], DSStoreError
    > {
        guard let superBlockNumber = allocator.tableOfContents["DSDB"] else {
            return .success([])
        }

        return allocator.blockData(number: Int(superBlockNumber)).flatMap { superBlockData in
            var reader = BinaryReader(data: superBlockData)
            return reader.readUInt32().flatMap { rootNode in
                reader.readUInt32()
                    .flatMap { _ in reader.readUInt32() }
                    .flatMap { _ in reader.readUInt32() }
                    .flatMap { _ in reader.readUInt32() }
                    .flatMap { _ in traverse(node: Int(rootNode), in: allocator) }
            }
        }
    }

    static func writeEntries(_ entries: [DSStoreEntry], into allocator: DSStoreBuddyAllocator)
        -> Result<Void, DSStoreError>
    {
        let pageSize = defaultPageSize
        let sortedEntries = entries.sorted()
        let existingSuperBlock = allocator.tableOfContents["DSDB"].map(Int.init)

        return allocator.allocate(size: 20, preferredBlockNumber: existingSuperBlock)
            .flatMap { superBlockNumber in
                buildLevels(sortedEntries, pageSize: pageSize, allocator: allocator)
                    .flatMap { rootNode, height, pageCount in
                        allocator.tableOfContents["DSDB"] = UInt32(superBlockNumber)
                        return writeSuperBlock(
                            blockNumber: superBlockNumber,
                            rootNode: rootNode,
                            height: height,
                            recordCount: sortedEntries.count,
                            pageCount: pageCount,
                            pageSize: pageSize,
                            into: allocator
                        )
                    }
            }
    }

    private static func buildLevels(
        _ entries: [DSStoreEntry],
        pageSize: Int,
        allocator: DSStoreBuddyAllocator
    ) -> Result<(rootNode: Int, height: Int, pageCount: Int), DSStoreError> {
        if entries.isEmpty {
            return allocator.allocate(size: pageSize).flatMap { blockNumber in
                makeNodeData(entries: [], childPointers: nil, pageSize: pageSize)
                    .flatMap {
                        allocator.writeBlock(number: blockNumber, data: $0, zeroFillTo: pageSize)
                    }
                    .map { (rootNode: blockNumber, height: 0, pageCount: 1) }
            }
        }

        var recordLevel = entries
        var childLevel: [Int] = []
        var pageCount = 0
        var height = 0

        while true {
            let sizes =
                childLevel.isEmpty
                ? recordLevel.map(\.byteSize)
                : recordLevel.map { 4 + $0.byteSize }
            let separators = partitionSizes(maximumBytes: pageSize - 8, sizes: sizes)
            let ranges = rangesForLevel(entryCount: recordLevel.count, separators: separators)

            let writeResult = ranges.traverse { range in
                let pageEntries = Array(recordLevel[range.lowerBound..<range.upperBound])
                let pagePointers =
                    childLevel.isEmpty
                    ? nil : Array(childLevel[range.lowerBound...range.upperBound])
                return allocator.allocate(size: pageSize).flatMap { blockNumber in
                    makeNodeData(
                        entries: pageEntries, childPointers: pagePointers, pageSize: pageSize
                    )
                    .flatMap {
                        allocator.writeBlock(number: blockNumber, data: $0, zeroFillTo: pageSize)
                    }
                    .map { blockNumber }
                }
            }

            switch writeResult {
            case .failure(let error):
                return .failure(error)
            case .success(let nextChildren):
                pageCount += nextChildren.count
                height += 1
                if nextChildren.count == 1 {
                    return .success(
                        (rootNode: nextChildren[0], height: height - 1, pageCount: pageCount))
                }

                recordLevel = separators.map { recordLevel[$0] }
                childLevel = nextChildren
            }
        }
    }

    private static func writeSuperBlock(
        blockNumber: Int,
        rootNode: Int,
        height: Int,
        recordCount: Int,
        pageCount: Int,
        pageSize: Int,
        into allocator: DSStoreBuddyAllocator
    ) -> Result<Void, DSStoreError> {
        var writer = BinaryWriter()
        writer.writeUInt32(UInt32(rootNode))
        writer.writeUInt32(UInt32(height))
        writer.writeUInt32(UInt32(recordCount))
        writer.writeUInt32(UInt32(pageCount))
        writer.writeUInt32(UInt32(pageSize))
        return allocator.writeBlock(number: blockNumber, data: writer.data, zeroFillTo: 20)
    }

    private static func traverse(node: Int, in allocator: DSStoreBuddyAllocator) -> Result<
        [DSStoreEntry], DSStoreError
    > {
        allocator.blockData(number: node)
            .flatMap(readNode(data:))
            .flatMap { entries, pointers in
                guard let pointers else {
                    return .success(entries)
                }

                guard pointers.count == entries.count + 1 else {
                    return .failure(.invalidBTreeNode)
                }

                var result: [DSStoreEntry] = []
                for index in entries.indices {
                    switch traverse(node: pointers[index], in: allocator) {
                    case .success(let children):
                        result.append(contentsOf: children)
                        result.append(entries[index])
                    case .failure(let error):
                        return .failure(error)
                    }
                }

                switch traverse(node: pointers[entries.count], in: allocator) {
                case .success(let children):
                    result.append(contentsOf: children)
                    return .success(result)
                case .failure(let error):
                    return .failure(error)
                }
            }
    }

    private static func readNode(data: Data) -> Result<([DSStoreEntry], [Int]?), DSStoreError> {
        var reader = BinaryReader(data: data)
        return reader.readUInt32().flatMap { tailPointerValue in
            reader.readUInt32().flatMap { countValue in
                let tailPointer = Int(tailPointerValue)
                let count = Int(countValue)

                if tailPointer == 0 {
                    return Array(0..<count).traverse { _ in
                        DSStoreEntry.read(from: &reader)
                    }.map { ($0, nil) }
                }

                return Array(0..<count).traverse { _ in
                    reader.readUInt32().flatMap { pointer in
                        DSStoreEntry.read(from: &reader).map { (Int(pointer), $0) }
                    }
                }.map { pointerAndEntries in
                    let pointers = pointerAndEntries.map(\.0) + [tailPointer]
                    let entries = pointerAndEntries.map(\.1)
                    return (entries, pointers)
                }
            }
        }
    }

    private static func makeNodeData(
        entries: [DSStoreEntry],
        childPointers: [Int]?,
        pageSize: Int
    ) -> Result<Data, DSStoreError> {
        var writer = BinaryWriter()

        if let childPointers {
            guard childPointers.count == entries.count + 1 else {
                return .failure(.invalidBTreeNode)
            }

            writer.writeUInt32(UInt32(childPointers.last ?? 0))
            writer.writeUInt32(UInt32(entries.count))
            for (entry, pointer) in zip(entries, childPointers) {
                writer.writeUInt32(UInt32(pointer))
                switch entry.write(to: &writer) {
                case .success:
                    break
                case .failure(let error):
                    return .failure(error)
                }
            }
        } else {
            writer.writeUInt32(0)
            writer.writeUInt32(UInt32(entries.count))
            for entry in entries {
                switch entry.write(to: &writer) {
                case .success:
                    break
                case .failure(let error):
                    return .failure(error)
                }
            }
        }

        writer.padZeroes(toCount: pageSize)
        return .success(writer.data)
    }

    private static func partitionSizes(maximumBytes: Int, sizes: [Int]) -> [Int] {
        let total = sizes.reduce(0, +)
        guard total > maximumBytes else {
            return []
        }

        let bucketCount = Int(ceil(Double(total) / Double(maximumBytes)))
        let target = Double(total) / Double(bucketCount)
        var separators: [Int] = []
        var index = 0

        while true {
            var bucketSize = 0
            while index < sizes.count, Double(bucketSize) < target,
                bucketSize + sizes[index] < maximumBytes
            {
                bucketSize += sizes[index]
                index += 1
            }

            guard index < sizes.count else {
                break
            }

            separators.append(index)
            index += 1
        }

        return separators
    }

    private static func rangesForLevel(entryCount: Int, separators: [Int]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var lowerBound = 0

        for separator in separators + [entryCount] {
            ranges.append(lowerBound..<separator)
            lowerBound = separator + 1
        }

        return ranges
    }
}

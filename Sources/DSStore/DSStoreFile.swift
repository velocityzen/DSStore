import FP
import Foundation

/// A complete Finder `.DS_Store` file represented as a sorted collection of entries.
public struct DSStoreFile: Equatable, Sendable {
    /// The records stored in the file, sorted by Finder filename and structure identifier.
    public var entries: [DSStoreEntry]

    /// Creates an in-memory store from the provided entries.
    ///
    /// - Parameter entries: The records to include in the store.
    public init(entries: [DSStoreEntry] = []) {
        self.entries = entries.sorted()
    }

    /// Decodes a `.DS_Store` file from raw bytes.
    ///
    /// - Parameter data: The serialized file contents.
    /// - Returns: A typed result containing the decoded store or a `DSStoreError`.
    public static func read(from data: Data) -> Result<Self, DSStoreError> {
        DSStoreBuddyAllocator.open(data: data)
            .flatMap { allocator in
                DSStoreBTree.readEntries(from: allocator)
            }
            .map(Self.init(entries:))
    }

    /// Loads and decodes a `.DS_Store` file from disk.
    ///
    /// - Parameter url: The file URL to read.
    /// - Returns: A typed result containing the decoded store or a `DSStoreError`.
    public static func read(from url: URL) -> Result<Self, DSStoreError> {
        do {
            let data = try Data(contentsOf: url)
            return read(from: data)
        } catch {
            return .failure(.ioError(error.localizedDescription))
        }
    }

    /// Encodes the current store to the on-disk `.DS_Store` format.
    ///
    /// - Returns: A typed result containing the encoded file data or a `DSStoreError`.
    public func data() -> Result<Data, DSStoreError> {
        let allocator = DSStoreBuddyAllocator()
        return DSStoreBTree.writeEntries(entries, into: allocator)
            .flatMap { allocator.writeMetadata() }
    }

    /// Writes the encoded store to disk.
    ///
    /// - Parameter url: The destination file URL.
    /// - Returns: A typed result containing `Void` on success or a `DSStoreError`.
    public func write(to url: URL) -> Result<Void, DSStoreError> {
        data().flatMap { encoded in
            do {
                try encoded.write(to: url)
                return .success(())
            } catch {
                return .failure(.ioError(error.localizedDescription))
            }
        }
    }
}

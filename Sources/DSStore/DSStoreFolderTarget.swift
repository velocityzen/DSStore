import Foundation

/// The resolved `.DS_Store` location and record name used to edit a folder's Finder settings.
public struct DSStoreFolderTarget: Equatable, Sendable {
    /// The folder being edited.
    public let folderURL: URL
    /// The `.DS_Store` file that should be read and written for that folder.
    public let storeURL: URL
    /// The Finder record name inside the backing store.
    public let recordName: String

    /// Resolves the correct `.DS_Store` file and record name for a folder path.
    ///
    /// Normal folders use the parent directory's `.DS_Store` with the child folder name as the record.
    /// Filesystem roots and volume roots use their own `.DS_Store` with `"."` as the record name.
    ///
    /// - Parameter folderURL: The folder to resolve.
    /// - Returns: A typed result containing the resolved target or a `DSStoreError`.
    public static func resolve(folderURL: URL) -> Result<Self, DSStoreError> {
        let standardized = folderURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            return .failure(.ioError("Folder does not exist at path: \(standardized.path)"))
        }

        let parentURL = standardized.deletingLastPathComponent()
        let isFileSystemRoot = parentURL == standardized
        let isVolumeRoot = parentURL.path == "/Volumes"

        if isFileSystemRoot || isVolumeRoot {
            return .success(
                Self(
                    folderURL: standardized,
                    storeURL: standardized.appending(path: ".DS_Store"),
                    recordName: "."
                )
            )
        }

        return .success(
            Self(
                folderURL: standardized,
                storeURL: parentURL.appending(path: ".DS_Store"),
                recordName: standardized.lastPathComponent
            )
        )
    }

    /// Reads the backing store for the resolved target, returning an empty store if none exists yet.
    public func readStore() -> Result<DSStoreFile, DSStoreError> {
        if FileManager.default.fileExists(atPath: storeURL.path) {
            return DSStoreFile.read(from: storeURL)
        }
        return .success(DSStoreFile())
    }

    /// Writes an updated store back to the resolved `.DS_Store` file.
    public func writeStore(_ store: DSStoreFile) -> Result<Void, DSStoreError> {
        store.write(to: storeURL)
    }
}

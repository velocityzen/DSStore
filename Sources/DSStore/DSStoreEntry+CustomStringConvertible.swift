import Foundation

extension DSStoreEntry: CustomStringConvertible {
    /// A human-readable summary of the entry suitable for dumps and logs.
    public var description: String {
        formattedDescription()
    }

    /// The human-readable meaning of the record's four-character structure ID.
    public var recordDescription: String {
        DSStoreHumanReadable.recordDescription(for: structureID)
    }

    /// Formats the entry as a tab-separated human-readable line.
    ///
    /// - Parameters:
    ///   - hexBlobs: When `true`, unknown blob values are rendered as hex.
    ///   - dateDisplay: Controls whether decoded dates use the local time zone or UTC.
    public func formattedDescription(
        hexBlobs: Bool = false,
        dateDisplay: DSStoreDateDisplay = .local
    ) -> String {
        DSStoreHumanReadable.describe(self, hexBlobs: hexBlobs, dateDisplay: dateDisplay)
    }

    /// Formats only the entry value using Finder-aware human-readable decoding.
    ///
    /// - Parameters:
    ///   - hexBlobs: When `true`, unknown blob values are rendered as hex.
    ///   - dateDisplay: Controls whether decoded dates use the local time zone or UTC.
    public func formattedValueDescription(
        hexBlobs: Bool = false,
        dateDisplay: DSStoreDateDisplay = .local
    ) -> String {
        DSStoreHumanReadable.describeValue(for: self, hexBlobs: hexBlobs, dateDisplay: dateDisplay)
    }
}

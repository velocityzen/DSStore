import Foundation

extension DSStoreValue: CustomStringConvertible {
    /// A human-readable summary of the value suitable for dumps and logs.
    public var description: String {
        formattedDescription()
    }

    /// Formats the value using Finder-aware human-readable decoding.
    ///
    /// - Parameters:
    ///   - hexBlobs: When `true`, blob values are rendered as hex where applicable.
    ///   - dateDisplay: Controls whether decoded dates use the local time zone or UTC.
    public func formattedDescription(
        hexBlobs: Bool = false,
        dateDisplay: DSStoreDateDisplay = .local
    ) -> String {
        DSStoreHumanReadable.describe(self, hexBlobs: hexBlobs, dateDisplay: dateDisplay)
    }
}

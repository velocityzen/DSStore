import FP
import Foundation

#if os(macOS)
    import DSStoreAliasBridge
#endif

/// A Finder folder background setting.
public enum DSStoreBackground: Equatable, Sendable {
    /// Use Finder's default background.
    case `default`
    /// Use a solid RGB color encoded as 16-bit channel values.
    case color(red: UInt16, green: UInt16, blue: UInt16)
    /// Use an image file referenced by Finder alias and bookmark data.
    case picture(aliasData: Data, bookmarkData: Data?)

    /// Parses a CSS-style hex color string into a Finder background color.
    ///
    /// Supported forms are `#rgb`, `#rrggbb`, and `#rrrrggggbbbb`.
    ///
    /// - Parameter hex: The input color string.
    /// - Returns: A typed result containing the parsed background or a `DSStoreError`.
    public static func color(hex: String) -> Result<Self, DSStoreError> {
        parseHexColor(hex).map { red, green, blue in
            .color(red: red, green: green, blue: blue)
        }
    }

    #if os(macOS)
        /// Builds a Finder picture background from an existing image file.
        ///
        /// The returned value contains the alias and bookmark payloads Finder expects inside icon
        /// view records such as `icvp` and `pBBk`.
        public static func picture(fileURL: URL) -> Result<Self, DSStoreError> {
            let standardized = fileURL.standardizedFileURL.resolvingSymlinksInPath()

            var isDirectory: ObjCBool = false
            guard
                FileManager.default.fileExists(
                    atPath: standardized.path, isDirectory: &isDirectory),
                !isDirectory.boolValue
            else {
                return .failure(.ioError("Image file does not exist at path: \(standardized.path)"))
            }

            let aliasResult: Result<Data, DSStoreError> = standardized.path.withCString { path in
                guard let aliasRef = DSStoreCreateAliasData(path)?.takeRetainedValue() else {
                    return .failure(
                        .unsupportedWriteValue(
                            "Could not create Finder alias data for \(standardized.path)"
                        ))
                }
                return .success(aliasRef as Data)
            }

            let bookmarkResult: Result<Data, DSStoreError>
            do {
                bookmarkResult = .success(
                    try standardized.bookmarkData(
                        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                        includingResourceValuesForKeys: [.nameKey],
                        relativeTo: nil
                    ))
            } catch {
                bookmarkResult = .failure(
                    .unsupportedWriteValue(
                        "Could not create Finder bookmark data for \(standardized.path): \(error.localizedDescription)"
                    ))
            }

            return aliasResult.flatMap { aliasData in
                bookmarkResult.map { bookmarkData in
                    .picture(aliasData: aliasData, bookmarkData: bookmarkData)
                }
            }
        }

        /// Writes image data to disk and builds a Finder picture background pointing at it.
        public static func picture(imageData: Data, writingTo fileURL: URL) -> Result<
            Self, DSStoreError
        > {
            let standardized = fileURL.standardizedFileURL.resolvingSymlinksInPath()
            let parent = standardized.deletingLastPathComponent()

            do {
                try FileManager.default.createDirectory(
                    at: parent, withIntermediateDirectories: true)
                try imageData.write(to: standardized, options: .atomic)
            } catch {
                return .failure(
                    .ioError(
                        "Could not write background image to \(standardized.path): \(error.localizedDescription)"
                    )
                )
            }

            return picture(fileURL: standardized)
        }
    #endif

    func legacyEntry(filename: String) -> Result<DSStoreEntry, DSStoreError> {
        switch self {
        case .default:
            return DSStoreEntry.make(
                filename: filename,
                structureID: "BKGD",
                value: .blob(Data([0x44, 0x65, 0x66, 0x42, 0, 0, 0, 0, 0, 0, 0, 0]))
            )
        case .color(let red, let green, let blue):
            let data = Data([
                0x43, 0x6C, 0x72, 0x42,
                UInt8(red >> 8), UInt8(red & 0xFF),
                UInt8(green >> 8), UInt8(green & 0xFF),
                UInt8(blue >> 8), UInt8(blue & 0xFF),
                0x00, 0x00,
            ])
            return DSStoreEntry.make(filename: filename, structureID: "BKGD", value: .blob(data))
        case .picture:
            return .failure(
                .unsupportedWriteValue(
                    "Picture backgrounds are stored in icon view records, not a BKGD blob"
                ))
        }
    }
}

/// A Finder window frame stored in `fwi0` and mirrored into `bwsp`.
public struct DSStoreWindowFrame: Equatable, Sendable {
    /// The left window coordinate.
    public let x: UInt16
    /// The top window coordinate.
    public let y: UInt16
    /// The window width.
    public let width: UInt16
    /// The window height.
    public let height: UInt16
    /// The four-character Finder view style, such as `icnv` or `clmv`.
    public let view: String

    let unknown0: UInt16
    let unknown1: UInt16

    /// Creates a validated window frame.
    ///
    /// - Parameters:
    ///   - x: The left window coordinate.
    ///   - y: The top window coordinate.
    ///   - width: The window width.
    ///   - height: The window height.
    ///   - view: The four-character Finder view style.
    /// - Returns: A typed result containing the frame or a `DSStoreError`.
    public static func make(
        x: UInt16,
        y: UInt16,
        width: UInt16,
        height: UInt16,
        view: String = "icnv"
    ) -> Result<Self, DSStoreError> {
        guard view.utf8.count == 4 else {
            return .failure(.invalidFourCharacterCode(view))
        }

        return .success(
            Self(
                x: x,
                y: y,
                width: width,
                height: height,
                view: view,
                unknown0: 0,
                unknown1: 0
            )
        )
    }

    init(
        x: UInt16,
        y: UInt16,
        width: UInt16,
        height: UInt16,
        view: String,
        unknown0: UInt16,
        unknown1: UInt16
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.view = view
        self.unknown0 = unknown0
        self.unknown1 = unknown1
    }

    func entry(filename: String) -> Result<DSStoreEntry, DSStoreError> {
        guard view.utf8.count == 4 else {
            return .failure(.invalidFourCharacterCode(view))
        }

        let bottom = y &+ height
        let right = x &+ width
        var data = Data()
        data.append(contentsOf: y.bigEndianBytes)
        data.append(contentsOf: x.bigEndianBytes)
        data.append(contentsOf: bottom.bigEndianBytes)
        data.append(contentsOf: right.bigEndianBytes)
        data.append(contentsOf: view.utf8)
        data.append(contentsOf: unknown0.bigEndianBytes)
        data.append(contentsOf: unknown1.bigEndianBytes)
        return DSStoreEntry.make(filename: filename, structureID: "fwi0", value: .blob(data))
    }

    static func decode(_ value: DSStoreValue?) -> Self? {
        guard case .blob(let data)? = value, data.count >= 16 else {
            return nil
        }

        guard
            let top = data.uint16(at: 0),
            let left = data.uint16(at: 2),
            let bottom = data.uint16(at: 4),
            let right = data.uint16(at: 6),
            let view = data.fourCharacterCode(at: 8),
            let unknown0 = data.uint16(at: 12),
            let unknown1 = data.uint16(at: 14)
        else {
            return nil
        }

        let width = right >= left ? right - left : 0
        let height = bottom >= top ? bottom - top : 0
        return Self(
            x: left,
            y: top,
            width: width,
            height: height,
            view: view,
            unknown0: unknown0,
            unknown1: unknown1
        )
    }
}

private func parseHexColor(_ value: String) -> Result<(UInt16, UInt16, UInt16), DSStoreError> {
    guard value.hasPrefix("#") else {
        return .failure(.unsupportedWriteValue("Color must start with #"))
    }

    let hex = String(value.dropFirst())
    switch hex.count {
    case 3:
        let chars = Array(hex)
        let expanded = chars.flatMap { [$0, $0, $0, $0] }
        return parse12DigitColor(String(expanded))
    case 6:
        let chars = Array(hex)
        let expanded = [
            chars[0], chars[1], chars[0], chars[1],
            chars[2], chars[3], chars[2], chars[3],
            chars[4], chars[5], chars[4], chars[5],
        ]
        return parse12DigitColor(String(expanded))
    case 12:
        return parse12DigitColor(hex)
    default:
        return .failure(.unsupportedWriteValue("Unsupported color format '\(value)'"))
    }
}

private func parse12DigitColor(_ hex: String) -> Result<(UInt16, UInt16, UInt16), DSStoreError> {
    guard hex.count == 12 else {
        return .failure(.unsupportedWriteValue("Color must contain 12 hex digits"))
    }

    let parts = stride(from: 0, to: 12, by: 4).map {
        String(
            hex[
                hex.index(
                    hex.startIndex, offsetBy: $0)..<hex.index(hex.startIndex, offsetBy: $0 + 4)])
    }

    let values = parts.traverse(parseUInt16)
    return values.map { ($0[0], $0[1], $0[2]) }
}

private func parseUInt16(_ hex: String) -> Result<UInt16, DSStoreError> {
    guard let value = UInt16(hex, radix: 16) else {
        return .failure(.unsupportedWriteValue("Invalid hex value '\(hex)'"))
    }
    return .success(value)
}

extension UInt16 {
    fileprivate var bigEndianBytes: [UInt8] {
        [UInt8(self >> 8), UInt8(self & 0xFF)]
    }
}

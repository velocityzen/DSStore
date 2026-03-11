import Foundation

enum DSStoreHumanReadable {
    private static let macEpochOffset: TimeInterval = -2_082_844_800
    static func describe(
        _ entry: DSStoreEntry,
        hexBlobs: Bool = false,
        dateDisplay: DSStoreDateDisplay = .local
    ) -> String {
        let label = recordDescription(for: entry.structureID)
        return
            "\(entry.filename)\t\(entry.structureID)\t\(label)\t\(describeValue(for: entry, hexBlobs: hexBlobs, dateDisplay: dateDisplay))"
    }

    static func describeValue(
        for entry: DSStoreEntry,
        hexBlobs: Bool = false,
        dateDisplay: DSStoreDateDisplay = .local
    ) -> String {
        switch (entry.structureID, entry.value) {
        case ("BKGD", let .blob(data)):
            return renderBackground(data, hexBlobs: hexBlobs)
        case ("Iloc", let .blob(data)):
            return renderIconLocation(data, hexBlobs: hexBlobs)
        case ("icgo", let .blob(data)):
            return renderTwoIntegerBlob(label: "icon grid options", data, hexBlobs: hexBlobs)
        case ("icsp", let .blob(data)):
            return renderTwoIntegerBlob(label: "icon spacing", data, hexBlobs: hexBlobs)
        case ("icvo", let .blob(data)):
            return renderIconViewOptions(data, hexBlobs: hexBlobs)
        case ("fwi0", let .blob(data)):
            return renderWindowFrame(data, hexBlobs: hexBlobs)
        case ("bwsp", let .blob(data)),
            ("icvp", let .blob(data)),
            ("lsvp", let .blob(data)),
            ("lsvP", let .blob(data)):
            return renderPropertyListBlob(data, hexBlobs: hexBlobs)
        case ("vstl", let .type(code)):
            return viewStyleName(code)
        case ("cmmt", let .unicodeString(string)):
            return "\"\(string)\""
        case ("ICVO", let .bool(flag)),
            ("LSVO", let .bool(flag)),
            ("dscl", let .bool(flag)):
            return flag ? "enabled" : "disabled"
        case ("icvt", let .short(size)),
            ("lsvt", let .short(size)),
            ("fwvh", let .short(size)):
            return "\(size) pt"
        case ("fwsw", let .long(width)):
            return "\(width) px"
        case ("logS", let .comp(size)), ("lg1S", let .comp(size)):
            return compactByteCount(size)
        case ("phyS", let .comp(size)), ("ph1S", let .comp(size)):
            return compactByteCount(size)
        case ("vSrn", let .long(value)):
            return "\(value)"
        case ("modD", let .dutc(value)), ("moDD", let .dutc(value)):
            return renderDUTC(value, dateDisplay: dateDisplay)
        case ("modD", let .blob(data)), ("moDD", let .blob(data)):
            return renderDUTCBlob(data, hexBlobs: hexBlobs, dateDisplay: dateDisplay)
        default:
            return describe(entry.value, hexBlobs: hexBlobs, dateDisplay: dateDisplay)
        }
    }

    static func describe(
        _ value: DSStoreValue,
        hexBlobs: Bool = false,
        dateDisplay: DSStoreDateDisplay = .local
    ) -> String {
        switch value {
        case .long(let number):
            return "\(number)"
        case .short(let number):
            return "\(number)"
        case .bool(let flag):
            return flag ? "true" : "false"
        case .blob(let data):
            if hexBlobs {
                return "blob 0x\(data.map { String(format: "%02x", $0) }.joined())"
            }
            return "blob \(data.count) bytes"
        case .type(let code):
            return code
        case .unicodeString(let string):
            return string
        case .comp(let number):
            return "\(number)"
        case .dutc(let number):
            return renderDUTC(number, dateDisplay: dateDisplay)
        }
    }

    static func recordDescription(for structureID: String) -> String {
        switch structureID {
        case "BKGD":
            return "background"
        case "bwsp":
            return "window settings plist"
        case "cmmt":
            return "Finder comment"
        case "dilc":
            return "desktop icon location cache"
        case "dscl":
            return "list disclosure state"
        case "extn":
            return "extension override"
        case "fwi0":
            return "Finder window frame"
        case "fwsw":
            return "sidebar width"
        case "fwvh":
            return "window vertical height"
        case "GRP0":
            return "group"
        case "icgo":
            return "icon grid options"
        case "icsp":
            return "icon spacing"
        case "icvo":
            return "icon view options"
        case "ICVO":
            return "icon view flag"
        case "icvp":
            return "icon view plist"
        case "icvt":
            return "icon label size"
        case "Iloc":
            return "icon location"
        case "info":
            return "Finder info blob"
        case "lg1S", "logS":
            return "logical size"
        case "lssp":
            return "list scroll position"
        case "lsvo":
            return "list view options"
        case "LSVO":
            return "list view flag"
        case "lsvP":
            return "list view plist"
        case "lsvp":
            return "list view columns plist"
        case "lsvt":
            return "list label size"
        case "moDD":
            return "modification date cache"
        case "modD":
            return "modification date cache"
        case "ph1S", "phyS":
            return "physical size"
        case "pict":
            return "background picture alias"
        case "type":
            return "four-char code"
        case "vSrn":
            return "view version"
        case "vstl":
            return "view style"
        default:
            return "record"
        }
    }

    private static func renderBackground(_ data: Data, hexBlobs: Bool) -> String {
        guard let code = data.fourCharacterCode(at: 0) else {
            return describe(.blob(data), hexBlobs: hexBlobs)
        }

        switch code {
        case "DefB":
            return "default"
        case "ClrB":
            guard let red = data.uint16(at: 4), let green = data.uint16(at: 6),
                let blue = data.uint16(at: 8)
            else {
                return describe(.blob(data), hexBlobs: hexBlobs)
            }
            return "#\(String(format: "%04x%04x%04x", red, green, blue))"
        case "PctB":
            guard let aliasLength = data.uint32(at: 4) else {
                return describe(.blob(data), hexBlobs: hexBlobs)
            }
            return "picture alias \(aliasLength) bytes"
        default:
            return describe(.blob(data), hexBlobs: hexBlobs)
        }
    }

    private static func renderIconLocation(_ data: Data, hexBlobs: Bool) -> String {
        guard let x = data.uint32(at: 0), let y = data.uint32(at: 4) else {
            return describe(.blob(data), hexBlobs: hexBlobs)
        }

        if let gridX = data.uint16(at: 8), let gridY = data.uint16(at: 10), data.count >= 16 {
            if gridX == 0xFFFF, gridY == 0xFFFF {
                return "x=\(x) y=\(y)"
            }
            return "x=\(x) y=\(y) grid=(\(gridX), \(gridY))"
        }

        return "x=\(x) y=\(y)"
    }

    private static func renderTwoIntegerBlob(label _: String, _ data: Data, hexBlobs: Bool)
        -> String
    {
        guard let first = data.uint32(at: 0), let second = data.uint32(at: 4) else {
            return describe(.blob(data), hexBlobs: hexBlobs)
        }
        return "\(first), \(second)"
    }

    private static func compactByteCount(_ size: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            .replacingOccurrences(of: " ", with: "")
    }

    private static func renderIconViewOptions(_ data: Data, hexBlobs: Bool) -> String {
        guard let code = data.fourCharacterCode(at: 0) else {
            return describe(.blob(data), hexBlobs: hexBlobs)
        }

        switch code {
        case "icv4":
            guard
                let iconSize = data.uint16(at: 4),
                let arrangeBy = data.fourCharacterCode(at: 6),
                let labelPosition = data.fourCharacterCode(at: 10)
            else {
                return describe(.blob(data), hexBlobs: hexBlobs)
            }

            let showItemInfo = (data[safe: 15] ?? 0) & 0x01 == 0x01
            let showPreview = (data[safe: 25] ?? 0) & 0x01 == 0x01
            return
                "size=\(iconSize) arrangeBy=\(arrangeBy) label=\(labelPosition) showItemInfo=\(showItemInfo) showPreview=\(showPreview)"
        case "icvo":
            guard let iconSize = data.uint16(at: 12), let arrangeBy = data.fourCharacterCode(at: 18)
            else {
                return describe(.blob(data), hexBlobs: hexBlobs)
            }
            return "size=\(iconSize) arrangeBy=\(arrangeBy)"
        default:
            return describe(.blob(data), hexBlobs: hexBlobs)
        }
    }

    private static func renderWindowFrame(_ data: Data, hexBlobs: Bool) -> String {
        guard
            let top = data.uint16(at: 0),
            let left = data.uint16(at: 2),
            let bottom = data.uint16(at: 4),
            let right = data.uint16(at: 6),
            let view = data.fourCharacterCode(at: 8)
        else {
            return describe(.blob(data), hexBlobs: hexBlobs)
        }

        let width = right >= left ? right - left : 0
        let height = bottom >= top ? bottom - top : 0
        return "x=\(left) y=\(top) width=\(width) height=\(height) view=\(viewStyleName(view))"
    }

    private static func renderPropertyListBlob(_ data: Data, hexBlobs: Bool) -> String {
        guard
            let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let description = renderPropertyListObject(object)
        else {
            return describe(.blob(data), hexBlobs: hexBlobs)
        }

        return description
    }

    private static func renderPropertyListObject(_ value: Any) -> String? {
        switch value {
        case let dictionary as [String: Any]:
            let pieces = dictionary.keys.sorted().compactMap { key -> String? in
                guard let nested = dictionary[key], let rendered = renderPropertyListObject(nested)
                else {
                    return nil
                }
                return "\"\(key)\": \(rendered)"
            }
            return "{\(pieces.joined(separator: ", "))}"
        case let array as [Any]:
            let pieces = array.compactMap(renderPropertyListObject)
            return "[\(pieces.joined(separator: ", "))]"
        case let string as String:
            return "\"\(string)\""
        case let bool as Bool:
            return bool ? "true" : "false"
        case let number as NSNumber:
            return "\(number)"
        case let data as Data:
            return "\"data(\(data.count) bytes)\""
        default:
            return nil
        }
    }

    private static func viewStyleName(_ code: String) -> String {
        switch code {
        case "icnv":
            return "icon"
        case "clmv":
            return "column"
        case "Nlsv":
            return "list"
        case "Flwv":
            return "coverflow"
        default:
            return code
        }
    }

    private static func renderDUTC(_ value: UInt64, dateDisplay: DSStoreDateDisplay) -> String {
        let seconds = Double(value) / 65536.0
        let date = Date(timeIntervalSince1970: seconds + macEpochOffset)
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        guard (1970...2100).contains(year) else {
            return "unknown date"
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = dateDisplay == .utc ? TimeZone(secondsFromGMT: 0) : .current
        return formatter.string(from: date)
    }

    private static func renderDUTCBlob(
        _ data: Data,
        hexBlobs: Bool,
        dateDisplay: DSStoreDateDisplay
    ) -> String {
        guard let value = data.uint64(at: 0), data.count == 8 else {
            return describe(.blob(data), hexBlobs: hexBlobs, dateDisplay: dateDisplay)
        }

        if let appleReferenceTime = data.littleEndianDouble(at: 0),
            let rendered = renderAppleReferenceDate(appleReferenceTime, dateDisplay: dateDisplay)
        {
            return rendered
        }

        let bigEndianDUTC = renderDUTC(value, dateDisplay: dateDisplay)
        if bigEndianDUTC != "unknown date" {
            return bigEndianDUTC
        }

        return "unknown date (raw: 0x\(data.map { String(format: "%02x", $0) }.joined()))"
    }

    private static func renderAppleReferenceDate(
        _ seconds: Double,
        dateDisplay: DSStoreDateDisplay
    ) -> String? {
        let date = Date(timeIntervalSinceReferenceDate: seconds)
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        guard (1970...2100).contains(year) else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = dateDisplay == .utc ? TimeZone(secondsFromGMT: 0) : .current
        return formatter.string(from: date)
    }
}

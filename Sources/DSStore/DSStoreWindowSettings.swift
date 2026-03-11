import Foundation

/// Groups optional window setting fields for selective updates.
///
/// Pass this to ``DSStoreFile/settingWindowSettings(_:for:)-6rma0`` to update
/// only the fields that are non-nil.
public struct DSStoreWindowUpdate: Equatable, Sendable {
    public let x: UInt16?
    public let y: UInt16?
    public let width: UInt16?
    public let height: UInt16?
    public let view: String?
    public let containerShowSidebar: Bool?
    public let showSidebar: Bool?
    public let showStatusBar: Bool?
    public let showTabView: Bool?
    public let showToolbar: Bool?

    public init(
        x: UInt16? = nil,
        y: UInt16? = nil,
        width: UInt16? = nil,
        height: UInt16? = nil,
        view: String? = nil,
        containerShowSidebar: Bool? = nil,
        showSidebar: Bool? = nil,
        showStatusBar: Bool? = nil,
        showTabView: Bool? = nil,
        showToolbar: Bool? = nil
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.view = view
        self.containerShowSidebar = containerShowSidebar
        self.showSidebar = showSidebar
        self.showStatusBar = showStatusBar
        self.showTabView = showTabView
        self.showToolbar = showToolbar
    }
}

/// Finder plist-backed window settings stored in the `bwsp` record.
public struct DSStoreWindowSettings: Equatable, Sendable {
    /// The window frame mirrored into the `WindowBounds` plist field when present.
    public let frame: DSStoreWindowFrame?
    /// The `ContainerShowSidebar` flag.
    public let containerShowSidebar: Bool?
    /// The `ShowSidebar` flag.
    public let showSidebar: Bool?
    /// The `ShowStatusBar` flag.
    public let showStatusBar: Bool?
    /// The `ShowTabView` flag.
    public let showTabView: Bool?
    /// The `ShowToolbar` flag.
    public let showToolbar: Bool?

    /// Creates a plist-backed Finder window settings value.
    public init(
        frame: DSStoreWindowFrame? = nil,
        containerShowSidebar: Bool? = nil,
        showSidebar: Bool? = nil,
        showStatusBar: Bool? = nil,
        showTabView: Bool? = nil,
        showToolbar: Bool? = nil
    ) {
        self.frame = frame
        self.containerShowSidebar = containerShowSidebar
        self.showSidebar = showSidebar
        self.showStatusBar = showStatusBar
        self.showTabView = showTabView
        self.showToolbar = showToolbar
    }
}

extension DSStoreWindowSettings {
    static func decode(_ entry: DSStoreEntry?) -> DSStoreWindowSettings? {
        guard case .blob(let data)? = entry?.value else {
            return nil
        }

        switch plistDictionary(from: data) {
        case .failure:
            return nil
        case .success(let dictionary):
            let frame: DSStoreWindowFrame?
            if let value = dictionary["WindowBounds"] as? String {
                switch parseWindowBounds(value) {
                case .success(let parsedFrame):
                    frame = parsedFrame
                case .failure:
                    frame = nil
                }
            } else {
                frame = nil
            }

            return DSStoreWindowSettings(
                frame: frame,
                containerShowSidebar: boolValue(dictionary["ContainerShowSidebar"]),
                showSidebar: boolValue(dictionary["ShowSidebar"]),
                showStatusBar: boolValue(dictionary["ShowStatusBar"]),
                showTabView: boolValue(dictionary["ShowTabView"]),
                showToolbar: boolValue(dictionary["ShowToolbar"])
            )
        }
    }

    static func frame(from entry: DSStoreEntry?) -> DSStoreWindowFrame? {
        decode(entry)?.frame
    }

    func entry(filename: String, existing: DSStoreEntry?) -> Result<DSStoreEntry, DSStoreError> {
        let dictionaryResult: Result<[String: Any], DSStoreError>
        if let existing, case .blob(let data) = existing.value {
            dictionaryResult = Self.plistDictionary(from: data)
        } else {
            dictionaryResult = .success([:])
        }

        return
            dictionaryResult
            .flatMap { dictionary in
                var updated = dictionary
                if let frame {
                    updated["WindowBounds"] = Self.windowBoundsString(frame)
                }
                if let containerShowSidebar {
                    updated["ContainerShowSidebar"] = containerShowSidebar
                }
                if let showSidebar {
                    updated["ShowSidebar"] = showSidebar
                }
                if let showStatusBar {
                    updated["ShowStatusBar"] = showStatusBar
                }
                if let showTabView {
                    updated["ShowTabView"] = showTabView
                }
                if let showToolbar {
                    updated["ShowToolbar"] = showToolbar
                }
                return Self.plistData(from: updated)
            }
            .flatMap { data in
                DSStoreEntry.make(filename: filename, structureID: "bwsp", value: .blob(data))
            }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        default:
            return nil
        }
    }

    private static func plistDictionary(from data: Data) -> Result<[String: Any], DSStoreError> {
        do {
            let object = try PropertyListSerialization.propertyList(from: data, format: nil)
            guard let dictionary = object as? [String: Any] else {
                return .failure(.invalidPropertyListObject)
            }
            return .success(dictionary)
        } catch {
            return .failure(.invalidPropertyList)
        }
    }

    private static func plistData(from dictionary: [String: Any]) -> Result<Data, DSStoreError> {
        do {
            return .success(
                try PropertyListSerialization.data(
                    fromPropertyList: dictionary,
                    format: .binary,
                    options: 0
                )
            )
        } catch {
            return .failure(.propertyListEncodingFailed)
        }
    }

    private static func windowBoundsString(_ frame: DSStoreWindowFrame) -> String {
        "{{\(frame.x), \(frame.y)}, {\(frame.width), \(frame.height)}}"
    }

    private static func parseWindowBounds(_ value: String) -> Result<
        DSStoreWindowFrame, DSStoreError
    > {
        let numbers =
            value
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard numbers.count == 4 else {
            return .failure(.invalidPropertyListObject)
        }

        let parsed = numbers.map { UInt16($0) }
        guard let x = parsed[0], let y = parsed[1], let width = parsed[2], let height = parsed[3]
        else {
            return .failure(.invalidPropertyListObject)
        }

        return DSStoreWindowFrame.make(x: x, y: y, width: width, height: height)
    }
}

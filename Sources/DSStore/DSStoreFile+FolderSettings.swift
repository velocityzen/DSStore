import Foundation

extension DSStoreFile {
    /// Returns a copy of the store with the background record updated for the given Finder filename.
    ///
    /// - Parameters:
    ///   - background: The background to store. Picture backgrounds update icon-view state and, on
    ///     macOS, also persist bookmark data in `pBBk`.
    ///   - filename: The Finder filename the record applies to. Use `"."` for the current folder record.
    /// - Returns: A typed result containing the updated store or a `DSStoreError`.
    public func withBackground(_ background: DSStoreBackground, for filename: String = ".")
        -> Result<Self, DSStoreError>
    {
        withIconViewBackground(background, for: filename)
            .flatMap { store in
                switch background {
                case .default, .color:
                    return background.legacyEntry(filename: filename)
                        .map { legacyEntry in
                            store.replacing(legacyEntry)
                                .removing(filename: filename, structureID: "pBBk")
                        }
                case .picture(_, let bookmarkData):
                    let withoutLegacy = store.removing(filename: filename, structureID: "BKGD")
                    guard let bookmarkData else {
                        return .success(
                            withoutLegacy.removing(filename: filename, structureID: "pBBk"))
                    }

                    return DSStoreEntry.make(
                        filename: filename,
                        structureID: "pBBk",
                        value: .blob(bookmarkData)
                    )
                    .map { withoutLegacy.replacing($0) }
                }
            }
    }

    /// Returns a copy of the store with both `fwi0` and `bwsp` updated for the given Finder filename.
    ///
    /// - Parameters:
    ///   - frame: The window frame to store.
    ///   - filename: The Finder filename the record applies to. Use `"."` for the current folder record.
    /// - Returns: A typed result containing the updated store or a `DSStoreError`.
    public func withWindowFrame(_ frame: DSStoreWindowFrame, for filename: String = ".")
        -> Result<
            Self, DSStoreError
        >
    {
        let existingBWSP = entries.first { $0.filename == filename && $0.structureID == "bwsp" }
        return frame.entry(filename: filename)
            .flatMap { fwi0Entry in
                DSStoreWindowSettings(frame: frame).entry(
                    filename: filename, existing: existingBWSP
                )
                .map { bwspEntry in
                    replacing(fwi0Entry).replacing(bwspEntry)
                }
            }
    }

    /// Returns the plist-backed Finder window settings for the given Finder filename.
    public func windowSettings(for filename: String = ".") -> DSStoreWindowSettings? {
        let bwspEntry = entries.first { $0.filename == filename && $0.structureID == "bwsp" }
        return DSStoreWindowSettings.decode(bwspEntry)
    }

    /// Returns a copy of the store with `bwsp` updated and `fwi0` synchronized when frame information is provided.
    ///
    /// - Parameters:
    ///   - settings: The plist-backed window settings to store.
    ///   - filename: The Finder filename the record applies to. Use `"."` for the current folder record.
    /// - Returns: A typed result containing the updated store or a `DSStoreError`.
    public func withWindowSettings(
        _ settings: DSStoreWindowSettings,
        for filename: String = "."
    ) -> Result<Self, DSStoreError> {
        let updatedStoreResult: Result<Self, DSStoreError>
        if let frame = settings.frame {
            updatedStoreResult = withWindowFrame(frame, for: filename)
        } else {
            updatedStoreResult = .success(self)
        }

        return updatedStoreResult.flatMap { store in
            let existingBWSP = store.entries.first {
                $0.filename == filename && $0.structureID == "bwsp"
            }
            return settings.entry(filename: filename, existing: existingBWSP)
                .map { store.replacing($0) }
        }
    }

    /// Returns a copy of the store with selected plist-backed Finder window settings updated.
    ///
    /// Omitted values preserve the current setting when one exists.
    ///
    /// - Parameters:
    ///   - update: The window settings to apply. Only non-nil fields are changed.
    ///   - filename: The Finder filename the record applies to. Use `"."` for the current folder record.
    /// - Returns: A typed result containing the updated store or a `DSStoreError`.
    public func withWindowSettings(
        _ update: DSStoreWindowUpdate,
        for filename: String = "."
    ) -> Result<Self, DSStoreError> {
        let currentFrame = windowFrame(for: filename)
        let shouldUpdateFrame =
            update.x != nil || update.y != nil || update.width != nil || update.height != nil
            || update.view != nil

        let frameResult: Result<DSStoreWindowFrame?, DSStoreError>
        if shouldUpdateFrame {
            guard let resolvedWidth = update.width ?? currentFrame?.width,
                let resolvedHeight = update.height ?? currentFrame?.height
            else {
                return .failure(
                    .unsupportedWriteValue(
                        "width and height are required when creating a window frame"
                    ))
            }

            frameResult =
                DSStoreWindowFrame.make(
                    x: update.x ?? currentFrame?.x ?? 0,
                    y: update.y ?? currentFrame?.y ?? 0,
                    width: resolvedWidth,
                    height: resolvedHeight,
                    view: update.view ?? currentFrame?.view ?? "icnv"
                )
                .map { frame in
                    DSStoreWindowFrame(
                        x: frame.x,
                        y: frame.y,
                        width: frame.width,
                        height: frame.height,
                        view: frame.view,
                        unknown0: currentFrame?.unknown0 ?? 0,
                        unknown1: currentFrame?.unknown1 ?? 0
                    )
                }
                .map(Optional.some)
        } else {
            frameResult = .success(nil)
        }

        return frameResult.flatMap { frame in
            withWindowSettings(
                DSStoreWindowSettings(
                    frame: frame,
                    containerShowSidebar: update.containerShowSidebar,
                    showSidebar: update.showSidebar,
                    showStatusBar: update.showStatusBar,
                    showTabView: update.showTabView,
                    showToolbar: update.showToolbar
                ),
                for: filename
            )
        }
    }

    /// Returns a copy of the store with the window frame updated, preserving omitted fields from the current value when available.
    ///
    /// - Parameters:
    ///   - filename: The Finder filename the record applies to. Use `"."` for the current folder record.
    ///   - x: The optional left window coordinate.
    ///   - y: The optional top window coordinate.
    ///   - width: The window width.
    ///   - height: The window height.
    ///   - view: The optional four-character Finder view style.
    /// - Returns: A typed result containing the updated store or a `DSStoreError`.
    public func withWindowFrame(
        for filename: String = ".",
        x: UInt16? = nil,
        y: UInt16? = nil,
        width: UInt16,
        height: UInt16,
        view: String? = nil
    ) -> Result<Self, DSStoreError> {
        let current = windowFrame(for: filename)
        return withWindowSettings(
            DSStoreWindowUpdate(
                x: x ?? current?.x,
                y: y ?? current?.y,
                width: width,
                height: height,
                view: view ?? current?.view
            ),
            for: filename
        )
    }

    /// Reads the stored window frame for the given Finder filename.
    ///
    /// This checks `fwi0` first and then falls back to `bwsp`.
    ///
    /// - Parameter filename: The Finder filename the record applies to.
    /// - Returns: The decoded frame if one is available.
    public func windowFrame(for filename: String = ".") -> DSStoreWindowFrame? {
        let entry = entries.first { $0.filename == filename && $0.structureID == "fwi0" }
        if let frame = DSStoreWindowFrame.decode(entry?.value) {
            return frame
        }

        let bwspEntry = entries.first { $0.filename == filename && $0.structureID == "bwsp" }
        return DSStoreWindowSettings.frame(from: bwspEntry)
    }

    /// Returns the legacy `BKGD` background entry for the given Finder filename, if present.
    ///
    /// Picture backgrounds are stored in icon-view records such as `icvp` and `pBBk`, so this only
    /// reports Finder's legacy default or solid-color blob.
    public func backgroundEntry(for filename: String = ".") -> DSStoreEntry? {
        entries.first { $0.filename == filename && $0.structureID == "BKGD" }
    }

    private func withIconViewBackground(_ background: DSStoreBackground, for filename: String)
        -> Result<Self, DSStoreError>
    {
        let existingICVP = entries.first { $0.filename == filename && $0.structureID == "icvp" }

        return Self.iconViewDictionary(from: existingICVP)
            .flatMap { dictionary in
                Self.iconViewEntry(background: background, filename: filename, existing: dictionary)
            }
            .flatMap { icvpEntry in
                DSStoreEntry.make(filename: filename, structureID: "vSrn", value: .long(1))
                    .map { versionEntry in
                        replacing(icvpEntry).replacing(versionEntry)
                    }
            }
    }

    private func replacing(_ entry: DSStoreEntry) -> Self {
        let filtered = entries.filter {
            !($0.filename == entry.filename && $0.structureID == entry.structureID)
        }
        return Self(entries: filtered + [entry])
    }

    private func removing(filename: String, structureID: String) -> Self {
        let filtered = entries.filter {
            !($0.filename == filename && $0.structureID == structureID)
        }
        return Self(entries: filtered)
    }

    private static func iconViewEntry(
        background: DSStoreBackground,
        filename: String,
        existing: [String: Any]
    ) -> Result<DSStoreEntry, DSStoreError> {
        var updated = existing
        ensureIconViewDefaults(in: &updated)

        switch background {
        case .default:
            updated["backgroundType"] = 0
            updated["backgroundColorRed"] = 1.0
            updated["backgroundColorGreen"] = 1.0
            updated["backgroundColorBlue"] = 1.0
            updated.removeValue(forKey: "backgroundImageAlias")
        case .color(let red, let green, let blue):
            updated["backgroundType"] = 0
            updated["backgroundColorRed"] = Double(red) / 65_535
            updated["backgroundColorGreen"] = Double(green) / 65_535
            updated["backgroundColorBlue"] = Double(blue) / 65_535
            updated.removeValue(forKey: "backgroundImageAlias")
        case .picture(let aliasData, _):
            updated["backgroundType"] = 2
            updated["backgroundColorRed"] = 1.0
            updated["backgroundColorGreen"] = 1.0
            updated["backgroundColorBlue"] = 1.0
            updated["backgroundImageAlias"] = aliasData
        }

        return plistData(from: updated)
            .flatMap { data in
                DSStoreEntry.make(filename: filename, structureID: "icvp", value: .blob(data))
            }
    }

    private static func ensureIconViewDefaults(in dictionary: inout [String: Any]) {
        if dictionary["arrangeBy"] == nil {
            dictionary["arrangeBy"] = "none"
        }
        if dictionary["axTextSize"] == nil {
            dictionary["axTextSize"] = 13.0
        }
        if dictionary["gridOffsetX"] == nil {
            dictionary["gridOffsetX"] = 0.0
        }
        if dictionary["gridOffsetY"] == nil {
            dictionary["gridOffsetY"] = 0.0
        }
        if dictionary["gridSpacing"] == nil {
            dictionary["gridSpacing"] = 54.0
        }
        if dictionary["iconSize"] == nil {
            dictionary["iconSize"] = 72.0
        }
        if dictionary["labelOnBottom"] == nil {
            dictionary["labelOnBottom"] = true
        }
        if dictionary["showIconPreview"] == nil {
            dictionary["showIconPreview"] = true
        }
        if dictionary["showItemInfo"] == nil {
            dictionary["showItemInfo"] = false
        }
        if dictionary["textSize"] == nil {
            dictionary["textSize"] = 13.0
        }
        if dictionary["viewOptionsVersion"] == nil {
            dictionary["viewOptionsVersion"] = 1
        }
    }

    private static func iconViewDictionary(from entry: DSStoreEntry?) -> Result<
        [String: Any], DSStoreError
    > {
        guard let entry else {
            return .success([:])
        }
        guard case .blob(let data) = entry.value else {
            return .failure(.invalidPropertyListObject)
        }
        return plistDictionary(from: data)
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
}

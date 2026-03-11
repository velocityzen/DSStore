import Foundation

extension DSStoreFile {
    /// Returns a copy of the store with the background record updated for the given Finder filename.
    ///
    /// - Parameters:
    ///   - background: The background to store.
    ///   - filename: The Finder filename the record applies to. Use `"."` for the current folder record.
    /// - Returns: A typed result containing the updated store or a `DSStoreError`.
    public func settingBackground(_ background: DSStoreBackground, for filename: String = ".")
        -> Result<Self, DSStoreError>
    {
        background.entry(filename: filename)
            .map { replacing($0) }
    }

    /// Returns a copy of the store with both `fwi0` and `bwsp` updated for the given Finder filename.
    ///
    /// - Parameters:
    ///   - frame: The window frame to store.
    ///   - filename: The Finder filename the record applies to. Use `"."` for the current folder record.
    /// - Returns: A typed result containing the updated store or a `DSStoreError`.
    public func settingWindowFrame(_ frame: DSStoreWindowFrame, for filename: String = ".")
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
    public func settingWindowSettings(
        _ settings: DSStoreWindowSettings,
        for filename: String = "."
    ) -> Result<Self, DSStoreError> {
        let updatedStoreResult: Result<Self, DSStoreError>
        if let frame = settings.frame {
            updatedStoreResult = settingWindowFrame(frame, for: filename)
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
    public func settingWindowSettings(
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
            settingWindowSettings(
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
    public func settingWindowFrame(
        for filename: String = ".",
        x: UInt16? = nil,
        y: UInt16? = nil,
        width: UInt16,
        height: UInt16,
        view: String? = nil
    ) -> Result<Self, DSStoreError> {
        let current = windowFrame(for: filename)
        return settingWindowSettings(
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

    /// Returns the raw background entry for the given Finder filename, if present.
    public func backgroundEntry(for filename: String = ".") -> DSStoreEntry? {
        entries.first { $0.filename == filename && $0.structureID == "BKGD" }
    }

    private func replacing(_ entry: DSStoreEntry) -> Self {
        let filtered = entries.filter {
            !($0.filename == entry.filename && $0.structureID == entry.structureID)
        }
        return Self(entries: filtered + [entry])
    }
}

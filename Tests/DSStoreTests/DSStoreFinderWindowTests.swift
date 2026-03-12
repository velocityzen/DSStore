#if os(macOS)
    import AppKit
    import Foundation
    import Testing

    @testable import DSStore

    @Suite("Finder Window Integration", .serialized)
    struct DSStoreFinderWindowTests {
        @Test("Finder icon view records match AppleScript and the resolved DS_Store path")
        func readsFinderIconViewRecords() throws {
            let scratch = try FinderScratchDirectory.make(folderName: "Icon Folder", itemCount: 2)
            defer { scratch.cleanup() }

            let target = try DSStoreFolderTarget.resolve(folderURL: scratch.folderURL).get()
            assertCleanStart(in: scratch, target: target)

            let output = try FinderScriptOutput.run(
                iconViewScript, arguments: [scratch.folderURL.path])

            let store = try waitForStore(
                at: target.storeURL,
                filename: target.recordName,
                expectedStructureIDs: Set(["icvp", "vSrn"]),
                timeout: 20
            )
            try assertResolvedStorePath(in: scratch, target: target)
            let roundTripped = try DSStoreFile.read(from: store.data().get()).get()

            #expect(roundTripped.entries == store.entries)
            #expect(Set(store.entries.map(\.filename)) == Set([target.recordName]))
            #expect(Set(store.entries.map(\.structureID)).isSuperset(of: Set(["icvp", "vSrn"])))
            #expect(output.string("currentView") == "icon view")

            if store.entries.contains(where: {
                $0.filename == target.recordName && $0.structureID == "bwsp"
            }) {
                try assertWindowSettings(in: store, filename: target.recordName, output: output)
            }
            try assertViewVersion(in: store, filename: target.recordName)

            let dictionary = try plistDictionary(
                entry(in: store, filename: target.recordName, structureID: "icvp"))

            #expect(stringValue(dictionary["arrangeBy"]) == "none")
            #expect(intValue(dictionary["iconSize"]) != nil)
            #expect(intValue(dictionary["textSize"]) != nil)
            #expect(intValue(dictionary["axTextSize"]) != nil)
            #expect(boolValue(dictionary["showItemInfo"]) != nil)
            #expect(boolValue(dictionary["showIconPreview"]) != nil)
            #expect(intValue(dictionary["backgroundType"]) != nil)
        }

        @Test("Finder list view records match AppleScript and the resolved DS_Store path")
        func readsFinderListViewRecords() throws {
            let scratch = try FinderScratchDirectory.make(folderName: "List Folder", itemCount: 2)
            defer { scratch.cleanup() }

            let target = try DSStoreFolderTarget.resolve(folderURL: scratch.folderURL).get()
            assertCleanStart(in: scratch, target: target)

            let output = try FinderScriptOutput.run(
                listViewScript, arguments: [scratch.folderURL.path])

            let store = try waitForStore(
                at: target.storeURL,
                filename: target.recordName,
                expectedStructureIDs: Set(["lsvC", "lsvp", "vSrn"])
            )
            try assertResolvedStorePath(in: scratch, target: target)
            let roundTripped = try DSStoreFile.read(from: store.data().get()).get()

            #expect(roundTripped.entries == store.entries)
            #expect(Set(store.entries.map(\.filename)) == Set([target.recordName]))
            #expect(
                Set(store.entries.map(\.structureID)).isSuperset(of: Set(["lsvC", "lsvp", "vSrn"])))
            #expect(output.string("currentView") == "list view")

            if store.entries.contains(where: {
                $0.filename == target.recordName && $0.structureID == "bwsp"
            }) {
                try assertWindowSettings(in: store, filename: target.recordName, output: output)
            }
            try assertViewVersion(in: store, filename: target.recordName)

            let lsvCDictionaryEntry = entry(
                in: store, filename: target.recordName, structureID: "lsvC")
            if case .blob(let data) = lsvCDictionaryEntry.value {
                #expect(!data.isEmpty)
            } else {
                Issue.record("Expected lsvC to be stored as a blob")
            }

            let dictionary = try plistDictionary(
                entry(in: store, filename: target.recordName, structureID: "lsvp"))

            #expect(intValue(dictionary["iconSize"]) != nil)
            #expect(intValue(dictionary["textSize"]) != nil)
            #expect(intValue(dictionary["axTextSize"]) != nil)
            #expect(boolValue(dictionary["calculateAllSizes"]) != nil)
            #expect(boolValue(dictionary["showIconPreview"]) != nil)
            #expect(boolValue(dictionary["useRelativeDates"]) != nil)
        }

        @Test("Finder column view records match AppleScript and the resolved DS_Store path")
        func readsFinderColumnViewRecords() throws {
            let scratch = try FinderScratchDirectory.make(folderName: "Column Folder", itemCount: 2)
            defer { scratch.cleanup() }

            let target = try DSStoreFolderTarget.resolve(folderURL: scratch.folderURL).get()
            assertCleanStart(in: scratch, target: target)

            let output = try FinderScriptOutput.run(
                columnViewScript, arguments: [scratch.folderURL.path])

            let store = try waitForStore(
                at: target.storeURL,
                filename: target.recordName,
                expectedStructureIDs: Set(["vSrn"]),
                timeout: 10
            )
            try assertResolvedStorePath(in: scratch, target: target)
            let roundTripped = try DSStoreFile.read(from: store.data().get()).get()

            #expect(roundTripped.entries == store.entries)
            #expect(Set(store.entries.map(\.filename)) == Set([target.recordName]))
            #expect(Set(store.entries.map(\.structureID)).isSuperset(of: Set(["vSrn"])))
            #expect(output.string("currentView") == "column view")

            if store.entries.contains(where: {
                $0.filename == target.recordName && $0.structureID == "bwsp"
            }) {
                try assertWindowSettings(in: store, filename: target.recordName, output: output)
            }
            try assertViewVersion(in: store, filename: target.recordName)
        }

        @Test("library picture background from file URL survives a Finder round trip")
        func writesPictureBackgroundFromFileURL() throws {
            let scratch = try FinderScratchDirectory.make(
                folderName: "Picture Folder", itemCount: 2)
            defer { scratch.cleanup() }

            let target = try DSStoreFolderTarget.resolve(folderURL: scratch.folderURL).get()
            assertCleanStart(in: scratch, target: target)

            let imageURL = try scratch.writeImage(named: "Background.png")
            let background = try DSStoreBackground.picture(fileURL: imageURL).get()
            let (expectedAliasData, _) = try pictureParts(from: background)

            try target.setBackgroundImage(at: imageURL).get()

            let store = try waitForStore(
                at: target.storeURL,
                filename: target.recordName,
                expectedStructureIDs: Set(["icvp", "pBBk", "vSrn"])
            )
            try assertResolvedStorePath(in: scratch, target: target)
            try assertPictureBackground(
                in: store,
                filename: target.recordName,
                expectedImageURL: imageURL,
                expectedAliasData: expectedAliasData,
                requireExactAlias: true
            )

            let output = try FinderScriptOutput.run(
                readPictureBackgroundScript,
                arguments: [scratch.folderURL.path]
            )
            #expect(output.string("currentView") == "icon view")

            let finderStore = try waitForStore(
                at: target.storeURL,
                filename: target.recordName,
                expectedStructureIDs: Set(["icvp", "pBBk", "vSrn"])
            )
            try assertPictureBackground(
                in: finderStore,
                filename: target.recordName,
                expectedImageURL: imageURL,
                expectedAliasData: expectedAliasData,
                requireExactAlias: false
            )
        }

        @Test("library picture background from image data survives a Finder round trip")
        func writesPictureBackgroundFromImageData() throws {
            let scratch = try FinderScratchDirectory.make(
                folderName: "Image Data Folder", itemCount: 2)
            defer { scratch.cleanup() }

            let target = try DSStoreFolderTarget.resolve(folderURL: scratch.folderURL).get()
            assertCleanStart(in: scratch, target: target)

            let imageURL = try target.setBackgroundImage(
                validPNGData(), named: "Folder Background.png"
            )
            .get()
            #expect(FileManager.default.fileExists(atPath: imageURL.path))
            #expect((try? Data(contentsOf: imageURL)) == validPNGData())

            let background = try DSStoreBackground.picture(fileURL: imageURL).get()
            let (expectedAliasData, _) = try pictureParts(from: background)

            let store = try waitForStore(
                at: target.storeURL,
                filename: target.recordName,
                expectedStructureIDs: Set(["icvp", "pBBk", "vSrn"])
            )
            try assertResolvedStorePath(in: scratch, target: target)
            try assertPictureBackground(
                in: store,
                filename: target.recordName,
                expectedImageURL: imageURL,
                expectedAliasData: expectedAliasData,
                requireExactAlias: true
            )

            let output = try FinderScriptOutput.run(
                readPictureBackgroundScript,
                arguments: [scratch.folderURL.path]
            )
            #expect(output.string("currentView") == "icon view")

            let finderStore = try waitForStore(
                at: target.storeURL,
                filename: target.recordName,
                expectedStructureIDs: Set(["icvp", "pBBk", "vSrn"])
            )
            try assertPictureBackground(
                in: finderStore,
                filename: target.recordName,
                expectedImageURL: imageURL,
                expectedAliasData: expectedAliasData,
                requireExactAlias: false
            )
        }

        private func assertCleanStart(
            in scratch: FinderScratchDirectory, target: DSStoreFolderTarget
        ) {
            #expect(!FileManager.default.fileExists(atPath: target.storeURL.path))
            #expect(
                !FileManager.default.fileExists(
                    atPath: scratch.folderURL.appending(path: ".DS_Store").path))
        }

        private func assertResolvedStorePath(
            in scratch: FinderScratchDirectory, target: DSStoreFolderTarget
        )
            throws
        {
            let stores = try scratch.dsStoreFiles()

            #expect(stores == [target.storeURL.standardizedFileURL])
            #expect(FileManager.default.fileExists(atPath: target.storeURL.path))
            #expect(
                !FileManager.default.fileExists(
                    atPath: scratch.folderURL.appending(path: ".DS_Store").path))
        }

        private func assertWindowSettings(
            in store: DSStoreFile,
            filename: String,
            output: FinderScriptOutput
        ) throws {
            guard let settings = store.windowSettings(for: filename) else {
                Issue.record("Missing bwsp window settings for \(filename)")
                return
            }

            guard let frame = settings.frame else {
                Issue.record("Missing WindowBounds frame for \(filename)")
                return
            }

            let sidebarVisible = output.int("sidebarWidth") > 0

            #expect(settings.containerShowSidebar == sidebarVisible)
            #expect(settings.showSidebar == sidebarVisible)
            #expect(settings.showStatusBar == output.bool("statusBarVisible"))
            #expect(settings.showToolbar == output.bool("toolbarVisible"))
            #expect(frame.x == output.uint16("boundLeft"))
            #expect(frame.y == expectedStoreY(from: output))
            #expect(frame.width == output.uint16("boundRight") - output.uint16("boundLeft"))
            #expect(frame.height == output.uint16("boundBottom") - output.uint16("boundTop"))
        }

        private func assertViewVersion(in store: DSStoreFile, filename: String) throws {
            let versionEntry = entry(in: store, filename: filename, structureID: "vSrn")
            #expect(versionEntry.value == .long(1))
        }

        private func entry(in store: DSStoreFile, filename: String, structureID: String)
            -> DSStoreEntry
        {
            guard
                let entry = store.entries.first(where: {
                    $0.filename == filename && $0.structureID == structureID
                })
            else {
                Issue.record("Missing \(structureID) entry for \(filename)")
                return try! DSStoreEntry.make(
                    filename: filename, structureID: structureID, value: .long(0)
                )
                .get()
            }
            return entry
        }

        private func expectedStoreY(from output: FinderScriptOutput) -> UInt16 {
            output.uint16("desktopMaxY") - output.uint16("boundBottom")
        }

        private func assertPictureBackground(
            in store: DSStoreFile,
            filename: String,
            expectedImageURL: URL,
            expectedAliasData: Data,
            requireExactAlias: Bool
        ) throws {
            let dictionary = try plistDictionary(
                entry(in: store, filename: filename, structureID: "icvp"))
            #expect(intValue(dictionary["backgroundType"]) == 2)
            let storedAlias = dataValue(dictionary["backgroundImageAlias"])
            #expect(storedAlias != nil)
            if requireExactAlias {
                #expect(storedAlias == expectedAliasData)
            }

            guard
                let bookmarkEntry = store.entries.first(where: {
                    $0.filename == filename && $0.structureID == "pBBk"
                })
            else {
                Issue.record("Missing pBBk entry for \(filename)")
                return
            }

            guard case .blob(let bookmarkData) = bookmarkEntry.value else {
                Issue.record("Expected pBBk to be stored as a bookmark blob")
                return
            }

            #expect(
                try resolvedBookmarkPath(from: bookmarkData)
                    == canonicalPath(expectedImageURL)
            )
            try assertViewVersion(in: store, filename: filename)
        }

        private func pictureParts(from background: DSStoreBackground) throws -> (Data, Data?) {
            guard case .picture(let aliasData, let bookmarkData) = background else {
                throw NSError(
                    domain: "DSStoreFinderWindowTests",
                    code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "Expected a picture background"]
                )
            }
            return (aliasData, bookmarkData)
        }

        private func waitForStore(
            at url: URL,
            filename: String,
            expectedStructureIDs: Set<String>,
            timeout: TimeInterval = 5,
            validator: ((DSStoreFile) -> Bool)? = nil
        ) throws -> DSStoreFile {
            let deadline = Date().addingTimeInterval(timeout)
            var lastStore: DSStoreFile?
            var lastError: Error?

            while Date() < deadline {
                do {
                    let store = try DSStoreFile.read(from: url).get()
                    lastStore = store

                    let actualStructureIDs = Set(
                        store.entries
                            .filter { $0.filename == filename }
                            .map(\.structureID)
                    )
                    if expectedStructureIDs.isSubset(of: actualStructureIDs)
                        && (validator?(store) ?? true)
                    {
                        return store
                    }
                } catch {
                    lastError = error
                }

                Thread.sleep(forTimeInterval: 0.2)
            }

            if let lastStore {
                return lastStore
            }

            throw lastError
                ?? NSError(
                    domain: "DSStoreFinderWindowTests",
                    code: 6,
                    userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(url.path)"]
                )
        }
    }

    private struct FinderScratchDirectory {
        let rootURL: URL
        let folderURL: URL

        static func make(folderName: String, itemCount: Int) throws -> Self {
            let rootURL = FileManager.default.temporaryDirectory
                .appending(path: "DSStore-Finder-\(UUID().uuidString)", directoryHint: .isDirectory)
            let folderURL = rootURL.appending(path: folderName, directoryHint: .isDirectory)

            try FileManager.default.createDirectory(
                at: folderURL, withIntermediateDirectories: true)
            for index in 1...itemCount {
                let fileURL = folderURL.appending(path: "Item \(index).txt")
                let created = FileManager.default.createFile(
                    atPath: fileURL.path,
                    contents: Data("Item \(index)\n".utf8)
                )
                if !created {
                    throw NSError(
                        domain: "DSStoreFinderWindowTests",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create \(fileURL.path)"]
                    )
                }
            }

            return Self(rootURL: rootURL, folderURL: folderURL)
        }

        func cleanup() {
            _ = try? FinderScriptOutput.run(closingWindowsScript, arguments: [folderURL.path])
            try? FileManager.default.removeItem(at: rootURL)
        }

        func dsStoreFiles() throws -> [URL] {
            guard
                let enumerator = FileManager.default.enumerator(
                    at: rootURL,
                    includingPropertiesForKeys: nil
                )
            else {
                throw NSError(
                    domain: "DSStoreFinderWindowTests",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate \(rootURL.path)"]
                )
            }

            var urls: [URL] = []
            for case let url as URL in enumerator where url.lastPathComponent == ".DS_Store" {
                urls.append(url.standardizedFileURL)
            }
            return urls.sorted { $0.path < $1.path }
        }

        func writeImage(named filename: String, data: Data = tinyPNGData) throws -> URL {
            let imageURL = rootURL.appending(path: filename)
            try data.write(to: imageURL, options: .atomic)
            return imageURL
        }
    }

    private struct FinderScriptOutput {
        let values: [String: String]

        static func run(_ script: String, arguments: [String]) throws -> Self {
            let stdout = try runAppleScript(script, arguments: arguments)
            return try Self(stdout: stdout)
        }

        init(stdout: String) throws {
            var values: [String: String] = [:]
            for rawLine in stdout.split(whereSeparator: \.isNewline) {
                let line = String(rawLine)
                guard let separatorIndex = line.firstIndex(of: "=") else {
                    throw NSError(
                        domain: "DSStoreFinderWindowTests",
                        code: 3,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Unexpected AppleScript output line: \(line)"
                        ]
                    )
                }

                let key = String(line[..<separatorIndex])
                let value = String(line[line.index(after: separatorIndex)...])
                values[key] = value
            }
            self.values = values
        }

        func string(_ key: String) -> String {
            values[key] ?? ""
        }

        func bool(_ key: String) -> Bool {
            string(key) == "true"
        }

        func int(_ key: String) -> Int {
            Int(string(key)) ?? 0
        }

        func uint16(_ key: String) -> UInt16 {
            UInt16(int(key))
        }
    }

    private func plistDictionary(_ entry: DSStoreEntry) throws -> [String: Any] {
        guard case .blob(let data) = entry.value else {
            throw NSError(
                domain: "DSStoreFinderWindowTests",
                code: 4,
                userInfo: [
                    NSLocalizedDescriptionKey: "Expected \(entry.structureID) to be a plist blob"
                ]
            )
        }

        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = object as? [String: Any] else {
            throw NSError(
                domain: "DSStoreFinderWindowTests",
                code: 5,
                userInfo: [
                    NSLocalizedDescriptionKey: "Expected plist dictionary for \(entry.structureID)"
                ]
            )
        }

        return dictionary
    }

    private func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        default:
            return nil
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        default:
            return nil
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        value as? String
    }

    private func dataValue(_ value: Any?) -> Data? {
        value as? Data
    }

    private func resolvedBookmarkPath(from data: Data) throws -> String {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return canonicalPath(url)
    }

    private func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func runAppleScript(_ script: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = ["-"] + arguments

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        stdin.fileHandleForWriting.write(Data(script.utf8))
        stdin.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        let stdoutData = try stdout.fileHandleForReading.readToEnd() ?? Data()
        let stderrData = try stderr.fileHandleForReading.readToEnd() ?? Data()

        guard process.terminationStatus == 0 else {
            let message = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "DSStoreFinderWindowTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message ?? "AppleScript failed"]
            )
        }

        return String(data: stdoutData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private let closingWindowsScript = #"""
        on run argv
            set childPath to item 1 of argv
            if childPath does not end with "/" then set childPath to childPath & "/"
            tell application "Finder"
                repeat with win in Finder windows
                    try
                        if (POSIX path of ((target of win) as alias)) is childPath then
                            close win
                        end if
                    end try
                end repeat
            end tell
        end run
        """#

    private let iconViewScript = #"""
        on run argv
            set childPath to item 1 of argv
            set folderAlias to POSIX file childPath as alias
            tell application "Finder"
                activate
                set desktopBounds to bounds of window of desktop
                set desktopMaxY to item 4 of desktopBounds
                set win to make new Finder window to folderAlias
                delay 1
                set current view of win to icon view
                delay 1
                set toolbar visible of win to true
                set statusbar visible of win to false
                set pathbar visible of win to true
                set bounds of win to {120, 140, 920, 740}
                set sidebar width of win to 180
                delay 1
                set arrangement of icon view options of win to not arranged
                set icon size of icon view options of win to 64
                set text size of icon view options of win to 15
                set shows item info of icon view options of win to true
                set shows icon preview of icon view options of win to false
                set background color of icon view options of win to {4369, 17476, 52428}
                delay 5

                close win
                delay 1
                set win2 to make new Finder window to folderAlias
                delay 2
                set actualBounds to bounds of win2
                set actualColor to background color of icon view options of win2
                set outputText to "desktopMaxY=" & desktopMaxY & linefeed & ¬
                    "currentView=" & (current view of win2 as string) & linefeed & ¬
                    "toolbarVisible=" & (toolbar visible of win2 as string) & linefeed & ¬
                    "statusBarVisible=" & (statusbar visible of win2 as string) & linefeed & ¬
                    "pathBarVisible=" & (pathbar visible of win2 as string) & linefeed & ¬
                    "sidebarWidth=" & (sidebar width of win2 as string) & linefeed & ¬
                    "boundLeft=" & (item 1 of actualBounds as string) & linefeed & ¬
                    "boundTop=" & (item 2 of actualBounds as string) & linefeed & ¬
                    "boundRight=" & (item 3 of actualBounds as string) & linefeed & ¬
                    "boundBottom=" & (item 4 of actualBounds as string) & linefeed & ¬
                    "iconSize=" & (icon size of icon view options of win2 as string) & linefeed & ¬
                    "textSize=" & (text size of icon view options of win2 as string) & linefeed & ¬
                    "showItemInfo=" & (shows item info of icon view options of win2 as string) & linefeed & ¬
                    "showIconPreview=" & (shows icon preview of icon view options of win2 as string) & linefeed & ¬
                    "backgroundColorRed=" & (item 1 of actualColor as string) & linefeed & ¬
                    "backgroundColorGreen=" & (item 2 of actualColor as string) & linefeed & ¬
                    "backgroundColorBlue=" & (item 3 of actualColor as string)
                close win2
                delay 4
                return outputText
            end tell
        end run
        """#

    private let listViewScript = #"""
        on run argv
            set childPath to item 1 of argv
            set folderAlias to POSIX file childPath as alias
            tell application "Finder"
                activate
                set desktopBounds to bounds of window of desktop
                set desktopMaxY to item 4 of desktopBounds
                set win to make new Finder window to folderAlias
                delay 1
                set current view of win to list view
                delay 1
                set toolbar visible of win to false
                set statusbar visible of win to false
                set pathbar visible of win to true
                set bounds of win to {160, 180, 940, 760}
                set sidebar width of win to 210
                delay 1
                set calculates folder sizes of list view options of win to true
                set shows icon preview of list view options of win to true
                set icon size of list view options of win to small icon
                set text size of list view options of win to 14
                set uses relative dates of list view options of win to true
                delay 2

                set actualBounds to bounds of win
                if (icon size of list view options of win) is small icon then
                    set listIconSizeValue to 16
                else
                    set listIconSizeValue to 32
                end if
                close win
                delay 1
                set win2 to make new Finder window to folderAlias
                delay 2
                set actualBounds to bounds of win2
                if (icon size of list view options of win2) is small icon then
                    set listIconSizeValue to 16
                else
                    set listIconSizeValue to 32
                end if
                set outputText to "desktopMaxY=" & desktopMaxY & linefeed & ¬
                    "currentView=" & (current view of win2 as string) & linefeed & ¬
                    "toolbarVisible=" & (toolbar visible of win2 as string) & linefeed & ¬
                    "statusBarVisible=" & (statusbar visible of win2 as string) & linefeed & ¬
                    "pathBarVisible=" & (pathbar visible of win2 as string) & linefeed & ¬
                    "sidebarWidth=" & (sidebar width of win2 as string) & linefeed & ¬
                    "boundLeft=" & (item 1 of actualBounds as string) & linefeed & ¬
                    "boundTop=" & (item 2 of actualBounds as string) & linefeed & ¬
                    "boundRight=" & (item 3 of actualBounds as string) & linefeed & ¬
                    "boundBottom=" & (item 4 of actualBounds as string) & linefeed & ¬
                    "listIconSize=" & (listIconSizeValue as string) & linefeed & ¬
                    "textSize=" & (text size of list view options of win2 as string) & linefeed & ¬
                    "calculatesFolderSizes=" & (calculates folder sizes of list view options of win2 as string) & linefeed & ¬
                    "showIconPreview=" & (shows icon preview of list view options of win2 as string) & linefeed & ¬
                    "usesRelativeDates=" & (uses relative dates of list view options of win2 as string)
                close win2
                delay 2
                return outputText
            end tell
        end run
        """#

    private let columnViewScript = #"""
        on run argv
            set childPath to item 1 of argv
            set folderAlias to POSIX file childPath as alias
            tell application "Finder"
                activate
                set desktopBounds to bounds of window of desktop
                set desktopMaxY to item 4 of desktopBounds
                set win to make new Finder window to folderAlias
                delay 1
                set current view of win to icon view
                delay 1
                set current view of win to column view
                delay 1
                set toolbar visible of win to true
                set statusbar visible of win to false
                set pathbar visible of win to false
                set bounds of win to {180, 220, 980, 840}
                set sidebar width of win to 250
                delay 1
                set text size of column view options of win to 16
                set shows icon of column view options of win to true
                set shows icon preview of column view options of win to false
                set shows preview column of column view options of win to true
                set discloses preview pane of column view options of win to false
                delay 2

                set actualBounds to bounds of win
                set outputText to "desktopMaxY=" & desktopMaxY & linefeed & ¬
                    "currentView=" & (current view of win as string) & linefeed & ¬
                    "toolbarVisible=" & (toolbar visible of win as string) & linefeed & ¬
                    "statusBarVisible=" & (statusbar visible of win as string) & linefeed & ¬
                    "pathBarVisible=" & (pathbar visible of win as string) & linefeed & ¬
                    "sidebarWidth=" & (sidebar width of win as string) & linefeed & ¬
                    "boundLeft=" & (item 1 of actualBounds as string) & linefeed & ¬
                    "boundTop=" & (item 2 of actualBounds as string) & linefeed & ¬
                    "boundRight=" & (item 3 of actualBounds as string) & linefeed & ¬
                    "boundBottom=" & (item 4 of actualBounds as string)
                close win
                delay 1
                set win2 to make new Finder window to folderAlias
                delay 2
                close win2
                delay 2
                return outputText
            end tell
        end run
        """#

    private let readPictureBackgroundScript = #"""
        on run argv
            set childPath to item 1 of argv
            set folderAlias to POSIX file childPath as alias
            tell application "Finder"
                activate
                set win to make new Finder window to folderAlias
                delay 1
                set current view of win to icon view
                delay 2

                set picturePath to ""
                try
                    set picturePath to POSIX path of ((background picture of icon view options of win) as alias)
                end try

                set outputText to "currentView=" & (current view of win as string) & linefeed & ¬
                    "backgroundPicturePath=" & picturePath
                close win
                delay 2
                return outputText
            end tell
        end run
        """#

    private func validPNGData() -> Data {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedRed: 0.89, green: 0.18, blue: 0.12, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor(calibratedRed: 0.99, green: 0.89, blue: 0.22, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 8, y: 8, width: 48, height: 48)).fill()
        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let data = rep.representation(using: .png, properties: [:])
        else {
            fatalError("Failed to build PNG test image")
        }

        return data
    }

    private let tinyPNGData = validPNGData()
#endif

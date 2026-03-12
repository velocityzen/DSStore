import Foundation
import Testing

@testable import DSStore

#if os(macOS)
    import AppKit
#endif

@Suite("DSStore")
struct DSStoreTests {
    @Test("reads the bundled Finder fixture")
    func readsFixture() throws {
        let file = try DSStoreFile.read(from: fixtureURL()).get()

        #expect(file.entries == expectedFixtureEntries())
    }

    @Test("round trips the bundled Finder fixture through the Swift encoder")
    func roundTripsFixture() throws {
        let original = try DSStoreFile.read(from: fixtureURL()).get()
        let encoded = try original.data().get()
        let decoded = try DSStoreFile.read(from: encoded).get()

        #expect(decoded.entries == original.entries)
    }

    @Test("writes and reads a multi-level B-tree")
    func writesLargeTree() throws {
        let entries = try (1...500).map { index in
            try DSStoreEntry.make(
                filename: "Number \(index)",
                structureID: "cmmt",
                value: .unicodeString(
                    "For filename [Number \(index)], this is a piece of text. This is yet more text. This is yet more text. This is yet more text. This is yet more text. This is yet more text."
                )
            ).get()
        }

        let store = DSStoreFile(entries: entries)
        let encoded = try store.data().get()
        let decoded = try DSStoreFile.read(from: encoded).get()

        #expect(decoded.entries == entries.sorted())
    }

    @Test("sets folder background through the library abstraction")
    func setsBackground() throws {
        let store = DSStoreFile()
        let updated = try store.withBackground(.color(red: 0x0000, green: 0x8888, blue: 0xFFFF))
            .get()
        let background = updated.backgroundEntry()!

        #expect(background.filename == ".")
        #expect(background.structureID == "BKGD")
        #expect(background.formattedValueDescription() == "#00008888ffff")
    }

    @Test("sets window frame through the library abstraction")
    func setsWindowFrame() throws {
        let store = DSStoreFile()
        let updated = try store.withWindowFrame(width: 800, height: 600).get()
        let frame = updated.windowFrame()

        #expect(frame?.x == 0)
        #expect(frame?.y == 0)
        #expect(frame?.width == 800)
        #expect(frame?.height == 600)
        #expect(frame?.view == "icnv")
        #expect(updated.entries.contains { $0.filename == "." && $0.structureID == "bwsp" })
    }

    @Test("reads window frame from bwsp when fwi0 is absent")
    func readsWindowFrameFromBWSP() throws {
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["WindowBounds": "{{40, 60}, {800, 600}}"],
            format: .binary,
            options: 0
        )
        let bwsp = try DSStoreEntry.make(filename: ".", structureID: "bwsp", value: .blob(plist))
            .get()
        let store = DSStoreFile(entries: [bwsp])

        let frame = store.windowFrame()

        #expect(frame?.x == 40)
        #expect(frame?.y == 60)
        #expect(frame?.width == 800)
        #expect(frame?.height == 600)
    }

    @Test("reads plist-backed bwsp flags")
    func readsWindowSettingsFromBWSP() throws {
        let plist = try PropertyListSerialization.data(
            fromPropertyList: [
                "ContainerShowSidebar": true,
                "ShowSidebar": true,
                "ShowStatusBar": false,
                "ShowTabView": false,
                "ShowToolbar": true,
                "WindowBounds": "{{40, 60}, {800, 600}}",
            ],
            format: .binary,
            options: 0
        )
        let bwsp = try DSStoreEntry.make(filename: ".", structureID: "bwsp", value: .blob(plist))
            .get()
        let store = DSStoreFile(entries: [bwsp])

        let settings = store.windowSettings()

        #expect(settings?.frame?.x == 40)
        #expect(settings?.frame?.y == 60)
        #expect(settings?.frame?.width == 800)
        #expect(settings?.frame?.height == 600)
        #expect(settings?.containerShowSidebar == true)
        #expect(settings?.showSidebar == true)
        #expect(settings?.showStatusBar == false)
        #expect(settings?.showTabView == false)
        #expect(settings?.showToolbar == true)
    }

    @Test("preserves existing bwsp keys when updating window frame")
    func preservesBWSPKeys() throws {
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["ShowSidebar": true, "WindowBounds": "{{10, 20}, {300, 200}}"],
            format: .binary,
            options: 0
        )
        let bwsp = try DSStoreEntry.make(filename: ".", structureID: "bwsp", value: .blob(plist))
            .get()
        let store = DSStoreFile(entries: [bwsp])

        let updated = try store.withWindowFrame(width: 900, height: 700).get()
        let updatedBWSP = updated.entries.first { $0.filename == "." && $0.structureID == "bwsp" }

        guard case .blob(let data)? = updatedBWSP?.value else {
            Issue.record("Missing bwsp blob after update")
            return
        }

        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        let dictionary = object as? [String: Any]

        #expect(dictionary?["ShowSidebar"] as? Bool == true)
        #expect(dictionary?["WindowBounds"] as? String == "{{10, 20}, {900, 700}}")
    }

    @Test("updates bwsp flags without overwriting window bounds")
    func updatesWindowSettingsFlags() throws {
        let plist = try PropertyListSerialization.data(
            fromPropertyList: [
                "ContainerShowSidebar": true,
                "ShowSidebar": true,
                "ShowStatusBar": true,
                "ShowToolbar": true,
                "WindowBounds": "{{10, 20}, {300, 200}}",
            ],
            format: .binary,
            options: 0
        )
        let bwsp = try DSStoreEntry.make(filename: ".", structureID: "bwsp", value: .blob(plist))
            .get()
        let store = DSStoreFile(entries: [bwsp])

        let updated = try store.withWindowSettings(
            DSStoreWindowUpdate(
                showSidebar: false,
                showStatusBar: false,
                showTabView: true
            )
        ).get()
        let updatedBWSP = updated.entries.first { $0.filename == "." && $0.structureID == "bwsp" }

        guard case .blob(let data)? = updatedBWSP?.value else {
            Issue.record("Missing bwsp blob after settings update")
            return
        }

        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        let dictionary = object as? [String: Any]

        #expect(dictionary?["ContainerShowSidebar"] as? Bool == true)
        #expect(dictionary?["ShowSidebar"] as? Bool == false)
        #expect(dictionary?["ShowStatusBar"] as? Bool == false)
        #expect(dictionary?["ShowTabView"] as? Bool == true)
        #expect(dictionary?["ShowToolbar"] as? Bool == true)
        #expect(dictionary?["WindowBounds"] as? String == "{{10, 20}, {300, 200}}")
    }

    @Test("resolves folder target to parent dsstore for non-root folders")
    func resolvesFolderTarget() throws {
        let parent = URL(fileURLWithPath: NSTemporaryDirectory()).appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        let child = parent.appending(path: "Child", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let target = try DSStoreFolderTarget.resolve(folderURL: child).get()

        #expect(target.storeURL == parent.appending(path: ".DS_Store"))
        #expect(target.recordName == "Child")
    }

    #if os(macOS)
        @Test("encodes picture background from a file URL")
        func encodesPictureBackgroundFromFileURL() throws {
            let scratch = try BackgroundScratchDirectory.make(folderName: "Picture Folder")
            defer { scratch.cleanup() }

            let imageURL = try scratch.writeImage(named: "Background.png")
            let background = try DSStoreBackground.picture(fileURL: imageURL).get()

            guard case .picture(let aliasData, let bookmarkData) = background else {
                Issue.record("Expected a picture background")
                return
            }

            #expect(!aliasData.isEmpty)
            #expect(bookmarkData != nil)
            #expect(try resolvedBookmarkPath(from: bookmarkData!) == canonicalPath(imageURL))
        }

        @Test("setBackgroundImage(at:) writes picture records to the resolved parent store")
        func setsPictureBackgroundFromFileURL() throws {
            let scratch = try BackgroundScratchDirectory.make(folderName: "Picture Folder")
            defer { scratch.cleanup() }

            let target = try DSStoreFolderTarget.resolve(folderURL: scratch.folderURL).get()
            #expect(!FileManager.default.fileExists(atPath: target.storeURL.path))
            #expect(
                !FileManager.default.fileExists(
                    atPath: scratch.folderURL.appending(path: ".DS_Store").path))

            let imageURL = try scratch.writeImage(named: "Background.png")
            try target.setBackgroundImage(at: imageURL).get()

            #expect(FileManager.default.fileExists(atPath: target.storeURL.path))
            #expect(
                !FileManager.default.fileExists(
                    atPath: scratch.folderURL.appending(path: ".DS_Store").path))

            let store = try target.readStore().get()
            let codes = Set(
                store.entries
                    .filter { $0.filename == target.recordName }
                    .map(\.structureID)
            )
            #expect(codes == Set(["icvp", "pBBk", "vSrn"]))
            try assertPictureEntries(
                in: store,
                filename: target.recordName,
                expectedImageURL: imageURL
            )
        }

        @Test("setBackgroundImage(_:named:) writes image data and picture records")
        func setsPictureBackgroundFromImageData() throws {
            let scratch = try BackgroundScratchDirectory.make(folderName: "Image Data Folder")
            defer { scratch.cleanup() }

            let target = try DSStoreFolderTarget.resolve(folderURL: scratch.folderURL).get()
            let imageURL = try target.setBackgroundImage(
                backgroundPNGData(), named: "Folder Background.png"
            )
            .get()

            #expect(FileManager.default.fileExists(atPath: imageURL.path))
            #expect(canonicalPath(imageURL).hasPrefix(canonicalPath(scratch.folderURL)))
            #expect((try? Data(contentsOf: imageURL)) == backgroundPNGData())
            #expect(FileManager.default.fileExists(atPath: target.storeURL.path))
            #expect(
                !FileManager.default.fileExists(
                    atPath: scratch.folderURL.appending(path: ".DS_Store").path))

            let store = try target.readStore().get()
            let codes = Set(
                store.entries
                    .filter { $0.filename == target.recordName }
                    .map(\.structureID)
            )
            #expect(codes == Set(["icvp", "pBBk", "vSrn"]))
            try assertPictureEntries(
                in: store,
                filename: target.recordName,
                expectedImageURL: imageURL
            )
        }
    #endif
}

private func expectedFixtureEntries() -> [DSStoreEntry] {
    [
        entry(
            "another file", "Iloc",
            .blob(
                Data([
                    0x00, 0x00, 0x00, 0x4F, 0x00, 0x00, 0x00, 0x38, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                    0xFF, 0x00, 0x00,
                ]))),
        entry("another file", "cmmt", .unicodeString("I am a file comment.")),
        entry(
            "Filename", "Iloc",
            .blob(
                Data([
                    0x00, 0x00, 0x00, 0x52, 0x00, 0x00, 0x00, 0x73, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                    0xFF, 0x00, 0x00,
                ]))),
        entry(
            "untitled folder", "BKGD",
            .blob(Data([0x44, 0x65, 0x66, 0x42, 0xBF, 0xFF, 0xF2, 0x78, 0x01, 0x80, 0x2E, 0xB4]))),
        entry("untitled folder", "ICVO", .bool(true)),
        entry(
            "untitled folder", "Iloc",
            .blob(
                Data([
                    0x00, 0x00, 0x00, 0x56, 0x00, 0x00, 0x00, 0xB1, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                    0xFF, 0x00, 0x00,
                ]))),
        entry(
            "untitled folder", "icgo",
            .blob(Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04]))),
        entry(
            "untitled folder", "icvo",
            .blob(
                Data([
                    0x69, 0x63, 0x76, 0x34, 0x00, 0x30, 0x6E, 0x6F, 0x6E, 0x65, 0x62, 0x6F, 0x74,
                    0x6D, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00,
                ]))),
        entry("untitled folder", "icvt", .short(13)),
    ]
}

private func fixtureURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Fixtures/store1")
}

private func entry(_ filename: String, _ structureID: String, _ value: DSStoreValue) -> DSStoreEntry
{
    try! DSStoreEntry.make(filename: filename, structureID: structureID, value: value).get()
}

#if os(macOS)
    private struct BackgroundScratchDirectory {
        let rootURL: URL
        let folderURL: URL

        static func make(folderName: String) throws -> Self {
            let rootURL = FileManager.default.temporaryDirectory
                .appending(
                    path: "DSStore-Background-\(UUID().uuidString)", directoryHint: .isDirectory)
            let folderURL = rootURL.appending(path: folderName, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: folderURL, withIntermediateDirectories: true)
            return Self(rootURL: rootURL, folderURL: folderURL)
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: rootURL)
        }

        func writeImage(named filename: String, data: Data = backgroundPNGData()) throws -> URL {
            let imageURL = rootURL.appending(path: filename)
            try data.write(to: imageURL, options: .atomic)
            return imageURL
        }
    }

    private func assertPictureEntries(
        in store: DSStoreFile, filename: String, expectedImageURL: URL
    )
        throws
    {
        let icvp = try entry(in: store, filename: filename, structureID: "icvp")
        guard case .blob(let icvpData) = icvp.value else {
            Issue.record("Expected icvp to be stored as a plist blob")
            return
        }

        let plist = try PropertyListSerialization.propertyList(from: icvpData, format: nil)
        guard let dictionary = plist as? [String: Any] else {
            Issue.record("Expected icvp plist dictionary")
            return
        }

        #expect((dictionary["backgroundType"] as? NSNumber)?.intValue == 2)
        #expect((dictionary["backgroundImageAlias"] as? Data)?.isEmpty == false)

        let bookmark = try entry(in: store, filename: filename, structureID: "pBBk")
        guard case .blob(let bookmarkData) = bookmark.value else {
            Issue.record("Expected pBBk to be stored as a bookmark blob")
            return
        }

        #expect(try resolvedBookmarkPath(from: bookmarkData) == canonicalPath(expectedImageURL))

        let version = try entry(in: store, filename: filename, structureID: "vSrn")
        #expect(version.value == .long(1))
    }

    private func entry(in store: DSStoreFile, filename: String, structureID: String) throws
        -> DSStoreEntry
    {
        guard
            let entry = store.entries.first(where: {
                $0.filename == filename && $0.structureID == structureID
            })
        else {
            throw NSError(
                domain: "DSStoreTests",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Missing \(structureID) entry for \(filename)"
                ]
            )
        }
        return entry
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

    private func backgroundPNGData() -> Data {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedRed: 0.14, green: 0.56, blue: 0.91, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor(calibratedRed: 0.97, green: 0.85, blue: 0.22, alpha: 1).setFill()
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
#endif

import Foundation
import Testing

@testable import DSStore

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
        let updated = try store.settingBackground(.color(red: 0x0000, green: 0x8888, blue: 0xFFFF))
            .get()
        let background = updated.backgroundEntry()!

        #expect(background.filename == ".")
        #expect(background.structureID == "BKGD")
        #expect(background.formattedValueDescription() == "#00008888ffff")
    }

    @Test("sets window frame through the library abstraction")
    func setsWindowFrame() throws {
        let store = DSStoreFile()
        let updated = try store.settingWindowFrame(width: 800, height: 600).get()
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

        let updated = try store.settingWindowFrame(width: 900, height: 700).get()
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

        let updated = try store.settingWindowSettings(
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

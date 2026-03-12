import ArgumentParser
import DSStore
import Foundation

extension DSStoreCLI {
    struct Window: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "window",
            abstract: "Update folder window and background settings."
        )

        @Argument(help: "Folder path to modify.")
        var folder: String

        @Option(name: .shortAndLong, help: "Window width in points.")
        var width: UInt16?

        @Option(name: .shortAndLong, help: "Window height in points.")
        var height: UInt16?

        @Option(name: .shortAndLong, help: "Window left position.")
        var x: UInt16?

        @Option(name: .shortAndLong, help: "Window top position.")
        var y: UInt16?

        @Option(name: .shortAndLong, help: "Finder view style 4CC such as icnv, clmv, or Nlsv.")
        var view: String?

        @Option(
            help:
                "Background value: default, a hex color like #08f, or a path to an image file."
        )
        var background: String?

        @Option(help: "Set bwsp ContainerShowSidebar.")
        var containerShowSidebar: Bool?

        @Option(help: "Set bwsp ShowSidebar.")
        var showSidebar: Bool?

        @Option(help: "Set bwsp ShowStatusBar.")
        var showStatusBar: Bool?

        @Option(help: "Set bwsp ShowTabView.")
        var showTabView: Bool?

        @Option(help: "Set bwsp ShowToolbar.")
        var showToolbar: Bool?

        func validate() throws {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder, isDirectory: &isDirectory),
                isDirectory.boolValue
            else {
                throw ValidationError("Folder does not exist at path: \(folder)")
            }

            if let view, view.utf8.count != 4 {
                throw ValidationError("--view must be exactly 4 characters")
            }

            if !hasWindowChanges && background == nil {
                throw ValidationError("No window or background options were provided")
            }
        }

        func run() throws {
            let result = DSStoreFolderTarget.resolve(folderURL: URL(filePath: folder))
                .flatMap { target in
                    target.readStore()
                        .flatMap { store in
                            applyBackground(to: store, recordName: target.recordName)
                        }
                        .flatMap { store in
                            applyWindowSettings(to: store, recordName: target.recordName)
                        }
                        .flatMap { target.writeStore($0) }
                        .map { target }
                }

            switch result {
            case .success(let target):
                print(
                    "Updated window settings for \(target.folderURL.path) via \(target.storeURL.path) record \(target.recordName)"
                )
            case .failure(let error):
                FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
                throw ExitCode.failure
            }
        }

        private var hasWindowChanges: Bool {
            x != nil || y != nil || width != nil || height != nil || view != nil
                || containerShowSidebar != nil || showSidebar != nil || showStatusBar != nil
                || showTabView != nil || showToolbar != nil
        }

        private func applyBackground(to store: DSStoreFile, recordName: String) -> Result<
            DSStoreFile, DSStoreError
        > {
            guard let background else {
                return .success(store)
            }

            let parsedBackground: Result<DSStoreBackground, DSStoreError>
            if background == "default" {
                parsedBackground = .success(.default)
            } else if FileManager.default.fileExists(atPath: background) {
                parsedBackground = DSStoreBackground.picture(
                    fileURL: URL(filePath: background))
            } else {
                parsedBackground = DSStoreBackground.color(hex: background)
            }

            return parsedBackground.flatMap { store.withBackground($0, for: recordName) }
        }

        private func applyWindowSettings(to store: DSStoreFile, recordName: String) -> Result<
            DSStoreFile, DSStoreError
        > {
            guard hasWindowChanges else {
                return .success(store)
            }

            return store.withWindowSettings(
                DSStoreWindowUpdate(
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    view: view,
                    containerShowSidebar: containerShowSidebar,
                    showSidebar: showSidebar,
                    showStatusBar: showStatusBar,
                    showTabView: showTabView,
                    showToolbar: showToolbar
                ),
                for: recordName
            )
        }
    }
}

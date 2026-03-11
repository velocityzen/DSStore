import ArgumentParser
import DSStore
import Darwin
import Foundation

extension DSStoreCLI {
    struct From: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "from",
            abstract: "Read a .DS_Store file and print its records."
        )

        enum OutputFormat: String, ExpressibleByArgument {
            case table
            case json
        }

        @Argument(help: "Path to the .DS_Store file to read.")
        var path: String

        @Option(name: .shortAndLong, help: "Output format: table or json.")
        var format: OutputFormat = .table

        @Flag(
            name: .shortAndLong,
            help: "Print blob values as hexadecimal instead of summarized text.")
        var hex = false

        @Flag(help: "Render dates in UTC instead of the local system time zone.")
        var utc = false

        func validate() throws {
            guard FileManager.default.fileExists(atPath: path) else {
                throw ValidationError("File does not exist at path: \(path)")
            }
        }

        func run() throws {
            let url = URL(filePath: path)
            switch DSStoreFile.read(from: url) {
            case .success(let store):
                switch format {
                case .table:
                    print(renderTable(store.entries))
                case .json:
                    print(try renderJSON(store.entries))
                }
            case .failure(let error):
                FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
                throw ExitCode.failure
            }
        }

        private func renderTable(_ entries: [DSStoreEntry]) -> String {
            let rows = entries.map {
                TableRow(
                    filename: $0.filename,
                    code: $0.structureID,
                    meaning: $0.recordDescription,
                    valueLines: renderTableValueLines(for: $0)
                )
            }

            let filenameWidth = max("Filename".count, rows.map(\.filename.count).max() ?? 0)
            let codeWidth = max("Code".count, rows.map(\.code.count).max() ?? 0)
            let meaningWidth = max("Meaning".count, rows.map(\.meaning.count).max() ?? 0)

            let header = [
                padded("Filename", to: filenameWidth),
                padded("Code", to: codeWidth),
                padded("Meaning", to: meaningWidth),
                "Value",
            ].joined(separator: "  ")

            let separator = [
                String(repeating: "-", count: filenameWidth),
                String(repeating: "-", count: codeWidth),
                String(repeating: "-", count: meaningWidth),
                String(repeating: "-", count: 5),
            ].joined(separator: "  ")

            let valueIndent = String(
                repeating: " ", count: filenameWidth + codeWidth + meaningWidth + 6)
            let body = rows.flatMap { row in
                guard let firstLine = row.valueLines.first else {
                    return [
                        [
                            padded(row.filename, to: filenameWidth),
                            padded(row.code, to: codeWidth),
                            padded(row.meaning, to: meaningWidth),
                            "",
                        ].joined(separator: "  ")
                    ]
                }

                let firstRow = [
                    padded(row.filename, to: filenameWidth),
                    padded(row.code, to: codeWidth),
                    padded(row.meaning, to: meaningWidth),
                    firstLine,
                ].joined(separator: "  ")

                let continuations = row.valueLines.dropFirst().map { line in
                    valueIndent + line
                }

                return [firstRow] + continuations
            }

            return ([header, separator] + body).joined(separator: "\n")
        }

        private func renderTableValueLines(for entry: DSStoreEntry) -> [String] {
            let value =
                prettyPrintedPropertyList(for: entry)
                ?? entry.formattedValueDescription(hexBlobs: hex, dateDisplay: dateDisplay)
            guard shouldUseColor, Self.isPropertyListRecord(entry.structureID) else {
                return value.components(separatedBy: "\n")
            }
            return highlightPlist(value).components(separatedBy: "\n")
        }

        private func renderJSON(_ entries: [DSStoreEntry]) throws -> String {
            let payload = entries.map {
                JSONEntry(
                    filename: $0.filename,
                    code: $0.structureID,
                    meaning: $0.recordDescription,
                    valueDescription: $0.formattedValueDescription(
                        hexBlobs: hex, dateDisplay: dateDisplay),
                    value: JSONValue($0.value)
                )
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            return String(decoding: data, as: UTF8.self)
        }

        private func padded(_ value: String, to width: Int) -> String {
            guard value.count < width else { return value }
            return value + String(repeating: " ", count: width - value.count)
        }

        private var dateDisplay: DSStoreDateDisplay {
            utc ? .utc : .local
        }

        private var shouldUseColor: Bool {
            guard isatty(STDOUT_FILENO) != 0 else { return false }
            let environment = ProcessInfo.processInfo.environment
            if environment["NO_COLOR"] != nil { return false }
            if environment["TERM"] == "dumb" { return false }
            return true
        }

        private func highlightPlist(_ value: String) -> String {
            let keyPattern = #""[^"]+"(?=\s*:)"#
            let stringPattern = #":\s*"[^"]*""#
            let boolPattern = #"\b(true|false)\b"#
            let numberPattern = #"\b\d+(\.\d+)?\b"#

            var highlighted = value
            highlighted = applyingColor(.cyan, regex: keyPattern, in: highlighted)
            highlighted = applyingColor(.green, regex: stringPattern, in: highlighted)
            highlighted = applyingColor(.magenta, regex: boolPattern, in: highlighted)
            highlighted = applyingColor(.yellow, regex: numberPattern, in: highlighted)
            return highlighted
        }

        private func applyingColor(_ color: ANSIColor, regex pattern: String, in value: String)
            -> String
        {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return value
            }

            let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
                .reversed()
            var result = value
            for match in matches {
                guard let range = Range(match.range, in: result) else { continue }
                let token = String(result[range])
                result.replaceSubrange(range, with: color.wrap(token))
            }
            return result
        }

        private static func isPropertyListRecord(_ code: String) -> Bool {
            ["bwsp", "icvp", "lsvp", "lsvP"].contains(code)
        }

        private func prettyPrintedPropertyList(for entry: DSStoreEntry) -> String? {
            guard Self.isPropertyListRecord(entry.structureID), case .blob(let data) = entry.value
            else {
                return nil
            }

            guard
                let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
                JSONSerialization.isValidJSONObject(object),
                let jsonData = try? JSONSerialization.data(
                    withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
                let json = String(data: jsonData, encoding: .utf8)
            else {
                return nil
            }

            return json
        }
    }
}

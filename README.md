# DSStore

Swift library and CLI for reading, writing, and editing Finder `.DS_Store` files.

The implementation is based on:

- MetaCPAN `Mac::Finder::DSStore` format notes
- Mozilla `DS_Store` format notes

## Documentation

DocC documentation is defined in [`Sources/DSStore/DSStore.docc`](Sources/DSStore/DSStore.docc) and can be built locally with:

```bash
swift package dump-symbol-graph
xcrun docc convert Sources/DSStore/DSStore.docc \
  --fallback-display-name DSStore \
  --fallback-bundle-identifier DSStore \
  --fallback-bundle-version 1.0.0 \
  --additional-symbol-graph-dir .build/arm64-apple-macosx/symbolgraph \
  --output-path .build/docc
```

## Features

- Read and write `.DS_Store` files
- Typed `Result`-based API with typed `DSStoreError`
- Human-readable record formatting via `CustomStringConvertible`
- Finder-specific decoding for common records such as `BKGD`, `Iloc`, `icvo`, `bwsp`, `fwi0`, `modD`, and `moDD`
- Folder-level editing helpers for background and window frame settings
- CLI for dumping records and editing folder settings

## Requirements

- Swift 6.2+
- macOS 14+ for the included CLI target

## Installation

From this package checkout:

```bash
swift build
```

To use the library from another SwiftPM package, add this package as a dependency using your preferred source location, then depend on:

```swift
.product(name: "DSStore", package: "DSStore")
```

## CLI

Build:

```bash
swift build
```

Read a `.DS_Store` file:

```bash
swift run dsstore from /path/to/.DS_Store
```

Useful `from` options:

- `--format table`
- `--format json`
- `--hex` for raw hex in table output for unknown blobs
- `--utc` to render dates in UTC instead of the local system time zone

Example:

```bash
swift run dsstore from --format json --utc /path/to/.DS_Store
```

JSON blob values are always emitted as hex:

```json
{
  "type": "blob",
  "string": "a92e75ecf3b0c741"
}
```

Update folder window and background settings:

```bash
swift run dsstore window /path/to/Folder --background default
swift run dsstore window /path/to/Folder --background '#08f'
swift run dsstore window /path/to/Folder --width 978 --height 830
swift run dsstore window /path/to/Folder --width 978 --height 830 --x 404 --y 99 --view icnv
swift run dsstore window /path/to/Folder --show-sidebar true --show-status-bar false --show-toolbar true
```

The `window` command takes a folder path, not a `.DS_Store` path. The library resolves the correct backing `.DS_Store` automatically:

- normal folder: parent folder’s `.DS_Store` + child folder name
- filesystem root or volume root: folder’s own `.DS_Store` + record name `.`

## Library Usage

Read a `.DS_Store` file:

```swift
import DSStore
import Foundation

let url = URL(filePath: "/path/to/.DS_Store")

switch DSStoreFile.read(from: url) {
case .success(let store):
  for entry in store.entries {
    print(entry.description)
  }
case .failure(let error):
  print(error.localizedDescription)
}
```

Read from in-memory data:

```swift
import DSStore
import Foundation

let data: Data = ...
let result = DSStoreFile.read(from: data)
```

Write a store back to disk:

```swift
let writeResult = store.write(to: url)
```

Create or update background settings:

```swift
import DSStore

let updated = DSStoreFile()
  .settingBackground(.default)

let colored = DSStoreFile()
  .settingBackground(.color(red: 0x1111, green: 0x4444, blue: 0xCCCC))

let parsedColor = DSStoreBackground.color(hex: "#1144cc")
```

Create or update window settings:

```swift
import DSStore

let result = DSStoreFile()
  .settingWindowSettings(
    DSStoreWindowUpdate(
      width: 978,
      height: 830,
      showSidebar: true,
      showStatusBar: false
    )
  )

let explicitFrame = DSStoreWindowFrame.make(
  x: 404,
  y: 99,
  width: 978,
  height: 830,
  view: "icnv"
)

let explicitSettings = DSStoreWindowSettings(
  frame: try? explicitFrame.get(),
  showSidebar: true,
  showToolbar: true
)
```

Resolve the correct store for a folder:

```swift
import DSStore
import Foundation

let folder = URL(filePath: "/path/to/Folder")

let result = DSStoreFolderTarget.resolve(folderURL: folder)
  .flatMap { target in
    target.readStore()
      .flatMap { store in
        store.settingWindowFrame(
          for: target.recordName,
          width: 978,
          height: 830
        )
      }
      .flatMap { target.writeStore($0) }
  }
```

## Output Formatting

`DSStoreEntry` and `DSStoreValue` provide human-readable formatting through `CustomStringConvertible`.

Examples:

- `physical size | 4KB`
- `background | default`
- `icon location | x=79 y=56`
- `modification date cache | 2026-03-11T14:11:36-04:00`

For plist-backed records such as `bwsp`, the CLI pretty-prints them as multi-line JSON-like output. When stdout is an interactive terminal, plist output is syntax-highlighted.

## Development

Run tests:

```bash
swift test
```

The test suite includes:

- parsing the bundled Finder fixture
- round-tripping real Finder data
- multi-level B-tree coverage
- background and window-setting mutation coverage
- error paths for invalid headers, corrupted data, and malformed entries

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
- Finder-specific decoding for common records such as `BKGD`, `Iloc`, `icvo`, `icvp`, `bwsp`, `fwi0`, `pBBk`, `modD`, and `moDD`
- Folder-level editing helpers for background and window frame settings
- macOS-only picture background helpers from a local file URL or raw image data
- CLI for dumping records and editing folder settings
- Finder integration tests that compare live Finder output against decoded records and the resolved backing `.DS_Store` path

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
dsstore from /path/to/.DS_Store
```

Useful `from` options:

- `--format table`
- `--format json`
- `--hex` for raw hex in table output for unknown blobs
- `--utc` to render dates in UTC instead of the local system time zone

Example:

```bash
dsstore from --format json --utc /path/to/.DS_Store
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
dsstore window /path/to/Folder --background default
dsstore window /path/to/Folder --background '#08f'
dsstore window /path/to/Folder --background /path/to/Background.png
dsstore window /path/to/Folder --width 978 --height 830
dsstore window /path/to/Folder --width 978 --height 830 --x 404 --y 99 --view icnv
dsstore window /path/to/Folder --show-sidebar true --show-status-bar false --show-toolbar true
```

The `window` command takes a folder path, not a `.DS_Store` path. The library resolves the correct backing `.DS_Store` automatically:

- normal folder: parent folder’s `.DS_Store` + child folder name
- filesystem root or volume root: folder’s own `.DS_Store` + record name `.`

The CLI supports `default`, solid-color, and picture backgrounds. When `--background` is a path to an existing image file, Finder picture background records are written using the macOS alias and bookmark APIs.

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
  .withBackground(.default)

let colored = DSStoreFile()
  .withBackground(.color(red: 0x1111, green: 0x4444, blue: 0xCCCC))

let parsedColor = DSStoreBackground.color(hex: "#1144cc")
```

Apply a Finder picture background from an existing image file on macOS:

```swift
import DSStore
import Foundation

let folder = URL(filePath: "/path/to/Folder")
let image = URL(filePath: "/path/to/Background.png")

let result = DSStoreFolderTarget.resolve(folderURL: folder)
  .flatMap { $0.setBackgroundImage(at: image) }
```

Write image data into the target folder and use it as the picture background on macOS:

```swift
import DSStore
import Foundation

let folder = URL(filePath: "/path/to/Folder")
let imageData: Data = ...

let result = DSStoreFolderTarget.resolve(folderURL: folder)
  .flatMap { $0.setBackgroundImage(imageData, named: "Folder Background.png") }
```

Build the lower-level picture background payload directly:

```swift
import DSStore
import Foundation

let image = URL(filePath: "/path/to/Background.png")
let background = DSStoreBackground.picture(fileURL: image)
```

Create or update window settings:

```swift
import DSStore

let result = DSStoreFile()
  .withWindowSettings(
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
        store.withWindowFrame(
          for: target.recordName,
          width: 978,
          height: 830
        )
      }
      .flatMap { target.writeStore($0) }
  }
```

Use the higher-level folder target convenience methods when you want Finder-style path resolution and immediate writes:

```swift
import DSStore
import Foundation

let folder = URL(filePath: "/path/to/Folder")

let result = DSStoreFolderTarget.resolve(folderURL: folder)
  .flatMap { target in
    target.setBackground(.default)
      .flatMap { target.readStore() }
  }
```

## Output Formatting

`DSStoreEntry` and `DSStoreValue` provide human-readable formatting through `CustomStringConvertible`.

Examples:

- `physical size | 4KB`
- `background | default`
- `background picture bookmark | blob 860 bytes`
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
- macOS Finder integration coverage for icon, list, column, and picture-background records
- fresh parent and child temp-folder coverage with no preexisting `.DS_Store`
- error paths for invalid headers, corrupted data, and malformed entries

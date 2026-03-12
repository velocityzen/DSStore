# ``DSStore``

Read, write, inspect, and edit Finder `.DS_Store` files in Swift.

## Overview

`DSStore` provides a typed, `Result`-based API for reading and writing Finder metadata files, plus higher-level helpers for common folder settings such as backgrounds and window frames. It also includes human-readable formatting for records and values so the same model types can power both applications and command-line inspection tools.

For folder editing, the package resolves the same backing `.DS_Store` location Finder uses for normal folders, filesystem roots, and volume roots. On macOS, it can also build Finder picture backgrounds from either an existing file URL or raw image bytes by writing the alias and bookmark payloads Finder expects in `icvp` and `pBBk`.

The macOS test suite includes Finder integration coverage that creates fresh parent and child folders with no preexisting `.DS_Store`, drives Finder through AppleScript, and verifies the resolved `.DS_Store` path and decoded record set against live Finder behavior.

## Topics

### Reading And Writing Stores
- ``DSStoreFile``
- ``DSStoreFile/entries``
- ``DSStoreFile/init(entries:)``
- ``DSStoreFile/read(from:)-(Data)``
- ``DSStoreFile/read(from:)-(URL)``
- ``DSStoreFile/data()``
- ``DSStoreFile/write(to:)``

### Working With Entries
- ``DSStoreEntry``
- ``DSStoreEntry/filename``
- ``DSStoreEntry/structureID``
- ``DSStoreEntry/value``
- ``DSStoreEntry/make(filename:structureID:value:)``

### Formatting Entries And Values
- ``DSStoreEntry/description``
- ``DSStoreEntry/recordDescription``
- ``DSStoreEntry/formattedDescription(hexBlobs:dateDisplay:)``
- ``DSStoreEntry/formattedValueDescription(hexBlobs:dateDisplay:)``
- ``DSStoreValue``
- ``DSStoreValue/long(_:)``
- ``DSStoreValue/short(_:)``
- ``DSStoreValue/bool(_:)``
- ``DSStoreValue/blob(_:)``
- ``DSStoreValue/type(_:)``
- ``DSStoreValue/unicodeString(_:)``
- ``DSStoreValue/comp(_:)``
- ``DSStoreValue/dutc(_:)``
- ``DSStoreValue/description``
- ``DSStoreValue/formattedDescription(hexBlobs:dateDisplay:)``
- ``DSStoreDateDisplay``
- ``DSStoreDateDisplay/local``
- ``DSStoreDateDisplay/utc``

### Folder Settings
- ``DSStoreBackground``
- ``DSStoreBackground/default``
- ``DSStoreBackground/color(red:green:blue:)``
- ``DSStoreBackground/color(hex:)``
- ``DSStoreBackground/picture(aliasData:bookmarkData:)``
- ``DSStoreBackground/picture(fileURL:)``
- ``DSStoreBackground/picture(imageData:writingTo:)``
- ``DSStoreWindowFrame``
- ``DSStoreWindowFrame/x``
- ``DSStoreWindowFrame/y``
- ``DSStoreWindowFrame/width``
- ``DSStoreWindowFrame/height``
- ``DSStoreWindowFrame/view``
- ``DSStoreWindowFrame/make(x:y:width:height:view:)``
- ``DSStoreWindowSettings``
- ``DSStoreWindowSettings/init(frame:containerShowSidebar:showSidebar:showStatusBar:showTabView:showToolbar:)``
- ``DSStoreWindowSettings/frame``
- ``DSStoreWindowSettings/containerShowSidebar``
- ``DSStoreWindowSettings/showSidebar``
- ``DSStoreWindowSettings/showStatusBar``
- ``DSStoreWindowSettings/showTabView``
- ``DSStoreWindowSettings/showToolbar``
- ``DSStoreFile/withBackground(_:for:)``
- ``DSStoreFile/windowSettings(for:)``
- ``DSStoreWindowUpdate``
- ``DSStoreWindowUpdate/init(x:y:width:height:view:containerShowSidebar:showSidebar:showStatusBar:showTabView:showToolbar:)``
- ``DSStoreFile/withWindowSettings(_:for:)-(DSStoreWindowSettings,_)``
- ``DSStoreFile/withWindowSettings(_:for:)-(DSStoreWindowUpdate,_)``
- ``DSStoreFile/withWindowFrame(_:for:)``
- ``DSStoreFile/withWindowFrame(for:x:y:width:height:view:)``
- ``DSStoreFile/windowFrame(for:)``
- ``DSStoreFile/backgroundEntry(for:)``

### Resolving Folder Targets
- ``DSStoreFolderTarget``
- ``DSStoreFolderTarget/folderURL``
- ``DSStoreFolderTarget/storeURL``
- ``DSStoreFolderTarget/recordName``
- ``DSStoreFolderTarget/resolve(folderURL:)``
- ``DSStoreFolderTarget/readStore()``
- ``DSStoreFolderTarget/writeStore(_:)``
- ``DSStoreFolderTarget/setBackground(_:)``
- ``DSStoreFolderTarget/setBackgroundImage(at:)``
- ``DSStoreFolderTarget/setBackgroundImage(_:named:)``

### Errors
- ``DSStoreError``
- ``DSStoreError/invalidFileHeader``
- ``DSStoreError/invalidMagic``
- ``DSStoreError/inconsistentRootOffsets``
- ``DSStoreError/invalidOffsetTable``
- ``DSStoreError/invalidBlockIdentifier(_:)``
- ``DSStoreError/invalidBlockRange``
- ``DSStoreError/invalidRootBlock``
- ``DSStoreError/invalidBTreeNode``
- ``DSStoreError/invalidRecordType(_:)``
- ``DSStoreError/invalidDataType(_:)``
- ``DSStoreError/invalidUTF16String``
- ``DSStoreError/invalidFourCharacterCode(_:)``
- ``DSStoreError/invalidPropertyList``
- ``DSStoreError/invalidPropertyListObject``
- ``DSStoreError/propertyListEncodingFailed``
- ``DSStoreError/unsupportedWriteValue(_:)``
- ``DSStoreError/ioError(_:)``
- ``DSStoreError/errorDescription``

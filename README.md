# PicDeck

PicDeck is a lightweight macOS menu bar app for quickly pasting frequently used images and GIFs. It watches a local media library folder, opens a searchable floating picker with a global shortcut, copies the selected file to the clipboard, and can paste it back into the app you were using.

## Features

- Menu bar app that stays out of the Dock.
- Global picker shortcut: `Option-Space`.
- Searchable media grid for images and GIFs.
- Import the current clipboard image into the library from the picker or menu bar.
- Library folder at `~/Pictures/PicDeck Library/`.
- Supported file types: `png`, `jpg`, `jpeg`, `gif`, `webp`, `heic`, and `tiff`.
- Optional automatic paste into the previously focused app after granting Accessibility permission.

## Requirements

- macOS 14.0 or later.
- Xcode with the macOS SDK installed.
- A local clone of this repository.

## Build With Xcode

1. Open `PicDeck.xcodeproj` in Xcode.
2. Select the `PicDeck` scheme.
3. Select your Mac as the run destination.
4. Open the target signing settings and choose your development team if Xcode asks for one.
5. Press `Command-B` to build, or `Command-R` to build and run.

## Build From Terminal

From the repository root:

```sh
xcodebuild \
  -project PicDeck.xcodeproj \
  -scheme PicDeck \
  -configuration Release \
  -derivedDataPath build
```

The built app will be available at:

```text
build/Build/Products/Release/PicDeck.app
```

If signing fails on your machine, open the project in Xcode and select your own development team in the PicDeck target settings, then build again.

## Install

After creating a Release build, copy the app to Applications:

```sh
cp -R build/Build/Products/Release/PicDeck.app /Applications/
```

Launch it from `/Applications/PicDeck.app`. PicDeck runs as a menu bar app, so look for the photo icon in the macOS menu bar instead of the Dock.

## First Run

1. Open PicDeck.
2. Click the PicDeck menu bar icon.
3. Choose **Open Library Folder**.
4. Add images or GIFs to `~/Pictures/PicDeck Library/`.
5. Choose **Import Image from Clipboard** to save the current clipboard image, or press `Option-Space` to open the picker and import from there.
6. Search or select an item, then press `Return` or click a thumbnail.

PicDeck will copy the selected file to the clipboard. To let PicDeck also paste automatically into the app you were using, grant Accessibility permission:

1. Click the PicDeck menu bar icon.
2. Choose **Request Accessibility Permission**.
3. In System Settings, enable PicDeck under **Privacy & Security > Accessibility**.
4. Quit and reopen PicDeck if macOS does not apply the permission immediately.

## Usage Notes

- `Option-Space` opens the picker from anywhere.
- `Command-Shift-V` imports the current clipboard image while the PicDeck menu is open.
- `Return` pastes the selected item.
- `Escape` closes the picker.
- The picker refreshes the library each time it opens.
- Filenames are used for search, so clear file names make the picker easier to use.

## Troubleshooting

If `Option-Space` does not open PicDeck, make sure the app is running and check that another app is not already using the same shortcut.

If selecting an item only copies it but does not paste it, grant Accessibility permission to PicDeck. Without that permission, macOS blocks PicDeck from sending `Command-V` to other apps.

If the picker is empty, add supported media files to `~/Pictures/PicDeck Library/` and open the picker again.

If macOS warns that the app cannot be opened because it is from an unidentified developer, build it locally with Xcode using your own signing team.

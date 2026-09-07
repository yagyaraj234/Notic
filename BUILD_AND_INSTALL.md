# Build and install Notic

Notic requires macOS 14 or later.

## Prerequisites

1. Install Xcode from the Mac App Store and open it once to finish setup.
2. Install XcodeGen:

   ```sh
   brew install xcodegen
   ```

3. If command-line tools point somewhere else, select the installed Xcode:

   ```sh
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

## Build and install

From the repository root, run:

```sh
./scripts/package.sh
```

This command:

- builds the Release app;
- verifies its code signature;
- replaces `/Applications/Notic.app` with the new build; and
- creates `dist/Notic-1.0.dmg` for installation on another Mac.

Open the installed app:

```sh
open /Applications/Notic.app
```

Notic runs in the menu bar. Press Option-Command-N to create a note.

## Install from the disk image

1. Open `dist/Notic-1.0.dmg`.
2. Drag `Notic.app` onto `Applications`.
3. In Applications, Control-click Notic and choose **Open**.
4. Confirm **Open** when macOS warns that the developer cannot be verified.

The warning appears because local builds are ad-hoc signed, not notarized with
an Apple Developer ID. On macOS 15 or later, you may need to choose **Done**,
then allow Notic in **System Settings > Privacy & Security > Open Anyway**.

## Build without installing

```sh
cd app
xcodegen generate
xcodebuild \
  -project Notic.xcodeproj \
  -scheme Notic \
  -configuration Release \
  -derivedDataPath ../DerivedData \
  build
```

Built app: `DerivedData/Build/Products/Release/Notic.app`.

## Verify before sharing

```sh
swift test
codesign --verify --deep --strict /Applications/Notic.app
```

Release distribution without the first-open warning additionally requires an
Apple Developer ID certificate, notarization, and stapling.

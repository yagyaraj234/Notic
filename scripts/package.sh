#!/bin/zsh
# Builds Notic in Release, installs it to /Applications, and writes a disk image
# to dist/ that can be handed to someone else.
#
# The build is ad-hoc signed (no Developer ID), so on another Mac Gatekeeper
# shows "cannot be opened because the developer cannot be verified" the first
# time. The README inside the disk image explains the right-click ▸ Open step.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
derived="${TMPDIR:-/tmp}/notic-release"
dist="$root/dist"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root/app/Notic/Info.plist" 2>/dev/null || echo 1.0)"

echo "Building Notic $version (Release)…"
cd "$root/app"
xcodegen generate --quiet
xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Release \
    -derivedDataPath "$derived" build 2>&1 | grep -E "error:|warning: .*\.swift|BUILD" || true

app="$derived/Build/Products/Release/Notic.app"
[[ -d "$app" ]] || { echo "Build failed: $app not found" >&2; exit 1; }
codesign --verify --deep --strict "$app"

echo "Installing to /Applications…"
pkill -x Notic 2>/dev/null || true
rm -rf /Applications/Notic.app
ditto "$app" /Applications/Notic.app

echo "Writing disk image…"
mkdir -p "$dist"
stage="$(mktemp -d)"
ditto "$app" "$stage/Notic.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/How to open Notic.txt" <<'EOF'
Notic — sticky notes on the edge of your screen (macOS 14 or later)

1. Drag Notic.app into the Applications folder alias next to it.
2. In Applications, right-click (or Control-click) Notic and choose Open.
   macOS will say the developer cannot be verified because this copy was not
   notarized with Apple. Click Open (on macOS 15 and later: click Done, then
   go to System Settings > Privacy & Security and click "Open Anyway").
   This is only needed the first time.
3. Notic lives in the menu bar. Move your pointer to the right edge of the
   screen to see your notes; press Option-Command-N for a new note.

Notic stores everything locally and never connects to the network.
EOF
dmg="$dist/Notic-$version.dmg"
rm -f "$dmg"
hdiutil create -quiet -volname "Notic $version" -srcfolder "$stage" -ov -format UDZO "$dmg"
rm -rf "$stage"

echo
echo "Installed:   /Applications/Notic.app"
echo "Share this:  $dmg"

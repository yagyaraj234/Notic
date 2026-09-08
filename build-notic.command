#!/bin/zsh
set -euo pipefail

root="${0:A:h}"
derived="$root/DerivedData"
built="$derived/Build/Products/Release/Notic.app"
output="$root/Notic.app"

command -v xcodegen >/dev/null || {
    echo "XcodeGen missing. Install it with: brew install xcodegen" >&2
    exit 1
}

cd "$root/app"
xcodegen generate --quiet
xcodebuild -quiet \
    -project Notic.xcodeproj \
    -scheme Notic \
    -configuration Release \
    -derivedDataPath "$derived" \
    build

codesign --verify --deep --strict "$built"
rm -rf "$output"
ditto "$built" "$output"

echo
echo "Ready: $output"
echo "Drag Notic.app into Applications."

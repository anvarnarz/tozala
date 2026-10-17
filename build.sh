#!/bin/zsh
# Builds Tozala.app and installs it to /Applications (or $DEST). Needs only Command Line Tools.
set -euo pipefail
cd "${0:A:h}"
DEST="${DEST:-/Applications}"
VERSION="$(cat VERSION)"
APP=build/Tozala.app

rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target arm64-apple-macos15 -swift-version 5 -parse-as-library \
  Sources/Tozala/*.swift -o "$APP/Contents/MacOS/Tozala"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/Fonts Resources/ertagakech-logo.svg "$APP/Contents/Resources/"

# Icon: drawn in code, then fanned out to an .icns
swiftc -O scripts/icon.swift -o build/icontool
build/icontool build/icon-1024.png
ICONSET=build/AppIcon.iconset && rm -rf $ICONSET && mkdir $ICONSET
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon-1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"   # ad-hoc: fine for this Mac

[[ "${1:-}" == "--no-install" ]] && { echo "Built $APP"; exit 0; }
pkill -x Tozala 2>/dev/null || true
rm -rf "$DEST/Tozala.app" && cp -R "$APP" "$DEST/"
/System/Library/CoreServices/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST/Tozala.app" 2>/dev/null \
  || /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST/Tozala.app"
echo "Installed $DEST/Tozala.app"

#!/bin/sh
# Install the complete signed desktop App and start its automatic service setup.
set -eu
VERSION=0.1.0
BASE=https://github.com/wandapp/wandapp.github.io/releases/download/macos-v$VERSION
ASSET=Wand-macOS-arm64.zip
fail() { printf '%s\n' "$*" >&2; exit 1; }
[ "$(uname -s)-$(uname -m)" = Darwin-arm64 ] || fail 'This release requires Apple Silicon macOS 13 or newer.'
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 13 ] || fail 'macOS 13 or newer is required.'
DEST=${WAND_APPLICATIONS_DIR:-$HOME/Applications}
case "$DEST" in /*) ;; *) fail 'Applications directory must be absolute.' ;; esac
mkdir -p "$DEST"
LOCK=$DEST/.wand-install.lock
mkdir "$LOCK" 2>/dev/null || fail 'Another Wand App installation is active.'
TEMP=$(mktemp -d "$DEST/.wand-download.XXXXXX")
cleanup() { rm -rf "$TEMP"; rmdir "$LOCK"; }
trap cleanup EXIT HUP INT TERM
curl --proto '=https' --tlsv1.2 -fLSs "$BASE/$ASSET" -o "$TEMP/$ASSET"
curl --proto '=https' --tlsv1.2 -fLSs "$BASE/$ASSET.sha256" -o "$TEMP/checksum"
HASH=$(awk -v file="$ASSET" '$2 == file && length($1)==64 {print $1}' "$TEMP/checksum")
case "$HASH" in ''|*[!a-fA-F0-9]*) fail 'Invalid checksum manifest.' ;; esac
[ "${#HASH}" = 64 ] || fail 'Invalid checksum length.'
printf '%s  %s\n' "$HASH" "$TEMP/$ASSET" | shasum -a 256 -c -
unzip -Z1 "$TEMP/$ASSET" > "$TEMP/entries"
awk '/^\// || /(^|\/)\.\.($|\/)/ || !/^Wand.app(\/|$)/ {bad=1} END {exit bad}' "$TEMP/entries" || fail 'Unsafe archive paths.'
ditto -x -k "$TEMP/$ASSET" "$TEMP"
APP=$TEMP/Wand.app
codesign --verify --deep --strict "$APP"
spctl --assess --type execute "$APP"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = dev.wandapp.macos ] || fail 'Unexpected application identifier.'
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "$VERSION" ] || fail 'Unexpected App version.'
# Never overwrite an unrelated App or replace an executable while it is running.
if [ -e "$DEST/Wand.app" ]; then
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEST/Wand.app/Contents/Info.plist")" = dev.wandapp.macos ] || fail 'An unrelated Wand.app already exists; nothing replaced.'
  if pgrep -f "$DEST/Wand.app/Contents/MacOS/" >/dev/null; then fail 'Quit Wand before updating. No App or Core process was stopped.'; fi
  NEW_EXEC=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")
  case "$NEW_EXEC" in ''|*/*|*..*) fail 'Invalid executable name.' ;; esac
  if cmp -s "$APP/Contents/MacOS/$NEW_EXEC" "$DEST/Wand.app/Contents/MacOS/$NEW_EXEC" && cmp -s "$APP/Contents/Info.plist" "$DEST/Wand.app/Contents/Info.plist" && cmp -s "$APP/Contents/_CodeSignature/CodeResources" "$DEST/Wand.app/Contents/_CodeSignature/CodeResources"; then
    printf 'This Wand build is already installed at %s/Wand.app.\n' "$DEST"
    open "$DEST/Wand.app"
    exit 0
  fi
  BACKUP=$DEST/Wand.previous.$(date +%Y%m%d%H%M%S).app
  [ ! -e "$BACKUP" ] || fail 'A backup with this timestamp already exists; retry shortly.'
  mv "$DEST/Wand.app" "$BACKUP"
  if ! mv "$APP" "$DEST/Wand.app"; then mv "$BACKUP" "$DEST/Wand.app"; fail 'Installation failed; previous App restored.'; fi
else
  mv "$APP" "$DEST/Wand.app"
fi
open "$DEST/Wand.app"
printf 'Installed and opened %s/Wand.app. Login startup and background services are registered by the App.\n' "$DEST"
printf 'If macOS requests background-item approval, complete the system prompt in Wand.\n' 

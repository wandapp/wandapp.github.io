#!/bin/sh
# Install the complete signed desktop App and start its automatic service setup.
# The version comes from the latest published release.json at run time; nothing is hardcoded here.
# WAND_RELEASE_URL overrides the release.json location (tests only; file:// is accepted only through it).
set -eu
ASSET=Wand-macOS-arm64.dmg
RELEASE_JSON_URL=${WAND_RELEASE_URL:-https://github.com/wandapp/app/releases/latest/download/release.json}
fail() { printf '%s\n' "$*" >&2; exit 1; }
[ "$(uname -s)-$(uname -m)" = Darwin-arm64 ] || fail 'This release requires Apple Silicon macOS 13 or newer.'
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 13 ] || fail 'macOS 13 or newer is required.'

# Resolve VERSION, the download URL and its sha256 from release.json (plutil ships with macOS).
# Schema 2: {"schema":2,"version","build","url","sha256","notarized"}. Only a notarized stable release installs here.
resolve_release() { # resolve_release FILE -> sets VERSION URL SHA
  key() { /usr/bin/plutil -extract "$1" raw -o - "$2" 2>/dev/null; }
  [ "$(key schema "$1")" = 2 ] || fail 'Unsupported release.json.'
  VERSION=$(key version "$1") || fail 'release.json has no version.'
  case "$VERSION" in ''|*[!0-9.]*|.*|*.|*..*) fail 'Invalid release version.' ;; esac
  [ "$(printf '%s' "$VERSION" | awk -F. '{print NF}')" = 3 ] || fail 'Invalid release version.'
  [ "$(key notarized "$1")" = true ] || fail 'The latest release is not notarized; nothing was installed.'
  URL=$(key url "$1") || fail 'release.json has no download URL.'
  [ "$URL" = "https://github.com/wandapp/app/releases/download/v$VERSION/$ASSET" ] || fail 'Unexpected download URL in release.json.'
  SHA=$(key sha256 "$1") || fail 'release.json has no checksum.'
  case "$SHA" in ''|*[!a-fA-F0-9]*) fail 'Invalid checksum in release.json.' ;; esac
  [ "${#SHA}" = 64 ] || fail 'Invalid checksum length.'
}
META=$(mktemp -d "${TMPDIR:-/tmp}/wand-release.XXXXXX")
trap 'rm -rf "$META"' EXIT HUP INT TERM
case "$RELEASE_JSON_URL" in
  https://*) PROTO=https ;;
  file://*) [ -n "${WAND_RELEASE_URL:-}" ] || fail 'Unexpected release location.'; PROTO=file ;;
  *) fail 'Unexpected release location.' ;;
esac
if [ "$PROTO" = https ]; then
  curl --proto '=https' --tlsv1.2 -fLSs "$RELEASE_JSON_URL" -o "$META/release.json" || fail 'Could not read release.json.'
else
  curl -fSs "$RELEASE_JSON_URL" -o "$META/release.json" || fail 'Could not read release.json.'
fi
resolve_release "$META/release.json"
rm -rf "$META"
if [ "${WAND_PRINT_PLAN:-}" = 1 ]; then printf 'version=%s\nurl=%s\nsha256=%s\n' "$VERSION" "$URL" "$SHA"; exit 0; fi
DEST=${WAND_APPLICATIONS_DIR:-$HOME/Applications}
case "$DEST" in /*) ;; *) fail 'Applications directory must be absolute.' ;; esac
mkdir -p "$DEST"
LOCK=$DEST/.wand-install.lock
mkdir "$LOCK" 2>/dev/null || fail 'Another Wand App installation is active.'
TEMP=$(mktemp -d "$DEST/.wand-download.XXXXXX")
cleanup() {
  if [ -d "$TEMP/mnt/Wand.app" ]; then hdiutil detach "$TEMP/mnt" >/dev/null 2>&1 || return; fi
  rm -rf "$TEMP"
  rmdir "$LOCK"
}
trap cleanup EXIT HUP INT TERM
curl --proto '=https' --tlsv1.2 -fLSs "$URL" -o "$TEMP/$ASSET"
printf '%s  %s\n' "$SHA" "$TEMP/$ASSET" | shasum -a 256 -c -
mkdir "$TEMP/mnt"
hdiutil attach -nobrowse -readonly -mountpoint "$TEMP/mnt" "$TEMP/$ASSET"
[ -d "$TEMP/mnt/Wand.app" ] || fail 'Wand.app is missing from the disk image.'
ditto "$TEMP/mnt/Wand.app" "$TEMP/Wand.app"
hdiutil detach "$TEMP/mnt"
APP=$TEMP/Wand.app
codesign --verify --deep --strict --all-architectures --test-requirement '=anchor apple generic and identifier "dev.wandapp.macos" and certificate leaf[subject.OU] = "3C4HSZQCL5" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$APP"
spctl --assess --type execute "$APP"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = dev.wandapp.macos ] || fail 'Unexpected application identifier.'
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "$VERSION" ] || fail 'Unexpected App version.'
# Never overwrite an unrelated App or replace an executable while it is running.
if [ -e "$DEST/Wand.app" ]; then
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEST/Wand.app/Contents/Info.plist")" = dev.wandapp.macos ] || fail 'An unrelated Wand.app already exists; nothing replaced.'
  NEW_EXEC=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")
  case "$NEW_EXEC" in ''|*/*|*..*) fail 'Invalid executable name.' ;; esac
  if cmp -s "$APP/Contents/MacOS/$NEW_EXEC" "$DEST/Wand.app/Contents/MacOS/$NEW_EXEC" && cmp -s "$APP/Contents/Info.plist" "$DEST/Wand.app/Contents/Info.plist" && cmp -s "$APP/Contents/_CodeSignature/CodeResources" "$DEST/Wand.app/Contents/_CodeSignature/CodeResources"; then
    printf 'This Wand build is already installed at %s/Wand.app.\n' "$DEST"
    open "$DEST/Wand.app"
    exit 0
  fi
  if pgrep -f "$DEST/Wand.app/Contents/MacOS/" >/dev/null; then fail 'Quit Wand before updating. No App or Core process was stopped.'; fi
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

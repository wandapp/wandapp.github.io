#!/bin/sh
# Bring this Mac to the latest stable Wand, whatever is installed now: the Core (services) first, then the
# signed App. Versions come from the latest published feeds at run time; nothing is hardcoded here.
# Live terminal sessions survive: the Core installer restarts only the gateway, never sessiond.
# --beta installs the newest build, stable or Beta, and keeps both the Core and the App on the Beta channel;
# without it, both go (back) to the stable channel.
# WAND_RELEASE_URL / WAND_MANIFEST_URL override the App / Core feeds (tests only; file:// only through them).
set -eu
ASSET=Wand-macOS-arm64.dmg
fail() { printf '%s\n' "$*" >&2; exit 1; }
CHANNEL=stable
for arg in "$@"; do
  case "$arg" in
    --beta) CHANNEL=beta ;;
    *) fail "Unknown option: $arg (only --beta is supported)" ;;
  esac
done
if [ "$CHANNEL" = beta ]; then
  RELEASE_JSON_URL=${WAND_RELEASE_URL:-https://github.com/wandapp/app/releases/download/beta/release.json}
  CORE_FEED=${WAND_MANIFEST_URL:-https://github.com/wandapp/core/releases/download/beta/manifest.json}
else
  RELEASE_JSON_URL=${WAND_RELEASE_URL:-https://github.com/wandapp/app/releases/latest/download/release.json}
  CORE_FEED=${WAND_MANIFEST_URL:-https://github.com/wandapp/core/releases/latest/download/manifest.json}
fi
# valid_version X.Y.Z or X.Y.Z-beta.N
valid_version() { printf '%s' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$'; }
# newer A B: A is a later version than B (semver: a release sorts after its betas)
newer() {
  key() { printf '%s' "$1" | awk -F'[.-]' '{ b = ($4 == "beta") ? $5 : 999999; printf "%09d%09d%09d%09d", $1, $2, $3, b }'; }
  [ "$(key "$1")" \> "$(key "$2")" ]
}
[ "$(uname -s)-$(uname -m)" = Darwin-arm64 ] || fail 'This release requires Apple Silicon macOS 13 or newer.'
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 13 ] || fail 'macOS 13 or newer is required.'

# Resolve VERSION, the download URL and its sha256 from release.json (plutil ships with macOS).
# Schema 2: {"schema":2,"version","build","url","sha256","notarized"}. Only a notarized stable release installs here.
resolve_release() { # resolve_release FILE -> sets VERSION URL SHA
  key() { /usr/bin/plutil -extract "$1" raw -o - "$2" 2>/dev/null; }
  [ "$(key schema "$1")" = 2 ] || fail 'Unsupported release.json.'
  VERSION=$(key version "$1") || fail 'release.json has no version.'
  valid_version "$VERSION" || fail 'Invalid release version.'
  NOTARIZED=$(key notarized "$1") || NOTARIZED=false
  # Stable is always notarized; a Beta is Developer ID signed (checked below) and may not be.
  [ "$NOTARIZED" = true ] || [ "$CHANNEL" = beta ] || fail 'The latest release is not notarized; nothing was installed.'
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

# The Core: same feed, checks and bundle installer as the Linux script and the updater.
CORE_RELEASES=https://github.com/wandapp/core/releases/download/v
CORE_PLATFORM=macos-arm64
CORE_HOME="$HOME/Library/Application Support/Wand/core"
json() { /usr/bin/plutil -extract "$1" raw -o - "$2" 2>/dev/null; }
CTEMP=$(mktemp -d "${TMPDIR:-/tmp}/wand-core.XXXXXX")
trap 'rm -rf "$CTEMP"' EXIT HUP INT TERM
case "$CORE_FEED" in
  https://*) curl --proto '=https' --tlsv1.2 -fLSs "$CORE_FEED" -o "$CTEMP/manifest.json" || fail 'Could not read the Core release feed.' ;;
  file://*) [ -n "${WAND_MANIFEST_URL:-}" ] || fail 'Unexpected Core feed location.'; curl -fSs "$CORE_FEED" -o "$CTEMP/manifest.json" || fail 'Could not read the Core release feed.' ;;
  *) fail 'Unexpected Core feed location.' ;;
esac
CORE_VERSION=$(json core.version "$CTEMP/manifest.json") || fail 'The Core feed has no version.'
CORE_URL=$(json "core.artifacts.$CORE_PLATFORM.url" "$CTEMP/manifest.json") || fail "Wand Core is not published for $CORE_PLATFORM."
CORE_SHA=$(json "core.artifacts.$CORE_PLATFORM.sha256" "$CTEMP/manifest.json") || fail 'The Core feed has no checksum.'
CORE_SIZE=$(json "core.artifacts.$CORE_PLATFORM.size" "$CTEMP/manifest.json") || fail 'The Core feed has no size.'
valid_version "$CORE_VERSION" || fail 'Invalid Core version.'
[ "$CORE_URL" = "$CORE_RELEASES$CORE_VERSION/wand-core-$CORE_VERSION-$CORE_PLATFORM.tar.gz" ] || fail 'Unexpected Core download URL.'
case "$CORE_SHA" in ''|*[!a-fA-F0-9]*) fail 'Invalid Core checksum.' ;; esac
[ "${#CORE_SHA}" = 64 ] || fail 'Invalid Core checksum length.'
# Keep the port the existing install uses (the web UI can change it); 3210 otherwise.
CORE_DATA=$(json data "$CORE_HOME/install.json") || CORE_DATA="$HOME/.wand-core"
PORT=$(json port "$CORE_DATA/network.json") || PORT=3210
case "$PORT" in ''|*[!0-9]*) PORT=3210 ;; esac
RUNNING=
curl -fsS -m 3 "http://127.0.0.1:$PORT/v1/hello" -o "$CTEMP/hello.json" 2>/dev/null && RUNNING=$(json version "$CTEMP/hello.json") || true

if [ "${WAND_PRINT_PLAN:-}" = 1 ]; then
  printf 'channel=%s\nversion=%s\nurl=%s\nsha256=%s\ncore=%s\ncoreUrl=%s\ncoreRunning=%s\nport=%s\n' "$CHANNEL" "$VERSION" "$URL" "$SHA" "$CORE_VERSION" "$CORE_URL" "${RUNNING:-none}" "$PORT"
  exit 0
fi

if [ "$RUNNING" = "$CORE_VERSION" ]; then
  printf 'Wand Core %s is already running on port %s.\n' "$CORE_VERSION" "$PORT"
elif [ "$CHANNEL" = stable ] && [ -n "$RUNNING" ] && valid_version "$RUNNING" && newer "$RUNNING" "$CORE_VERSION"; then
  # Never step a Beta back: it moves to stable with the next stable release that is newer.
  printf 'Wand Core %s is newer than the latest stable %s; kept, and it follows stable from now on.\n' "$RUNNING" "$CORE_VERSION"
else
  printf 'Updating Wand Core %s -> %s (port %s)...\n' "${RUNNING:-not running}" "$CORE_VERSION" "$PORT"
  curl --proto '=https' --tlsv1.2 -fLSs "$CORE_URL" -o "$CTEMP/core.tar.gz" || fail 'Could not download Wand Core.'
  [ "$(wc -c < "$CTEMP/core.tar.gz" | tr -d ' ')" = "$CORE_SIZE" ] || fail 'Downloaded Core size does not match the feed.'
  printf '%s  %s\n' "$CORE_SHA" "$CTEMP/core.tar.gz" | shasum -a 256 -c - >/dev/null || fail 'Core checksum mismatch; nothing was installed.'
  tar -tzf "$CTEMP/core.tar.gz" | awk '/^\// || /(^|\/)\.\.($|\/)/ || !/^(\.\/)?wand-core(\/|$)/ {bad=1} END {exit bad}' || fail 'Unsafe Core archive paths.'
  mkdir "$CTEMP/x" && tar -xzf "$CTEMP/core.tar.gz" -C "$CTEMP/x"
  xattr -dr com.apple.quarantine "$CTEMP/x" 2>/dev/null || true
  sh "$CTEMP/x/wand-core/install.sh" --instance core --port "$PORT" </dev/null || fail 'Wand Core installation failed.'
  for _ in $(seq 1 60); do
    curl -fsS -m 2 "http://127.0.0.1:$PORT/v1/hello" -o "$CTEMP/hello.json" 2>/dev/null && [ "$(json version "$CTEMP/hello.json")" = "$CORE_VERSION" ] && break
    sleep 1
  done
  [ "$(json version "$CTEMP/hello.json" 2>/dev/null)" = "$CORE_VERSION" ] || fail "Wand Core $CORE_VERSION was installed but is not answering on port $PORT; see $CORE_DATA/gatewayd.log."
  printf 'Wand Core %s is running on port %s. Open terminal sessions were kept.\n' "$CORE_VERSION" "$PORT"
fi
# The channel later updates follow (the Core updater and the App's「接收 Beta 更新」).
mkdir -p "$CORE_HOME/state" && printf '%s' "$CHANNEL" > "$CORE_HOME/state/channel"
defaults write dev.wandapp.macos wand.beta -bool "$([ "$CHANNEL" = beta ] && echo true || echo false)"
rm -rf "$CTEMP"
trap - EXIT HUP INT TERM

# The App: update the copy already installed (often /Applications from the disk image), else ~/Applications.
if [ -n "${WAND_APPLICATIONS_DIR:-}" ]; then DEST=$WAND_APPLICATIONS_DIR
elif [ -d /Applications/Wand.app ] && [ -w /Applications ]; then DEST=/Applications
else DEST=$HOME/Applications; fi
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
printf '%s  %s\n' "$SHA" "$TEMP/$ASSET" | shasum -a 256 -c - >/dev/null || fail 'App checksum mismatch; nothing was installed.'
mkdir "$TEMP/mnt"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$TEMP/mnt" "$TEMP/$ASSET"
[ -d "$TEMP/mnt/Wand.app" ] || fail 'Wand.app is missing from the disk image.'
ditto "$TEMP/mnt/Wand.app" "$TEMP/Wand.app"
hdiutil detach -quiet "$TEMP/mnt"
APP=$TEMP/Wand.app
codesign --verify --deep --strict --all-architectures --test-requirement '=anchor apple generic and identifier "dev.wandapp.macos" and certificate leaf[subject.OU] = "3C4HSZQCL5" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$APP"
[ "$NOTARIZED" != true ] || spctl --assess --type execute "$APP"
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
  if pgrep -f "$DEST/Wand.app/Contents/MacOS/" >/dev/null; then
    # Quit it the normal way (terminal sessions live in the Core, not the App) and reopen it below.
    osascript -e 'quit app id "dev.wandapp.macos"' >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do pgrep -f "$DEST/Wand.app/Contents/MacOS/" >/dev/null || break; sleep 0.5; done
    if pgrep -f "$DEST/Wand.app/Contents/MacOS/" >/dev/null; then fail 'Wand did not quit; quit it and run this again. The Core is already up to date.'; fi
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

#!/bin/sh
# Bring this Mac to the latest stable Wand, whatever is installed now. Wand on a Mac is one thing: the signed App,
# and the Core it carries (gateway, terminal service, web client). This installs the App from its release feed, then
# runs the App's own Core from inside it, and ends only when every module answers on that build:
# the gateway and the web client by restarting the gateway, the terminal service by restarting it too (running
# terminals are interrupted and restored in their directories; agents resume their conversations).
# Each App release carries the Core published with it, so nothing here reads the Core feed.
# --beta installs the newest build, stable or Beta, and keeps updates on the Beta channel; without it, stable.
# Either way the update source becomes the official feed (a Mac this one followed is forgotten).
# A build newer than the feed (a local one) is kept, never downgraded; its own Core is still brought in line.
# WAND_RELEASE_URL overrides the App feed (tests only; file:// only through it). WAND_PRINT_PLAN=1 prints the plan.
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
else
  RELEASE_JSON_URL=${WAND_RELEASE_URL:-https://github.com/wandapp/app/releases/latest/download/release.json}
fi
# valid_version X.Y.Z or X.Y.Z-beta.N
valid_version() { printf '%s' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$'; }
# newer A A_BUILD B B_BUILD: (A, A_BUILD) is a later build than (B, B_BUILD) (semver: a release sorts after its betas)
newer() {
  key() { printf '%s %s' "$1" "${2:-0}" | awk '{ split($1, p, /[.-]/); b = (p[4] == "beta") ? p[5] : 999999; printf "%09d%09d%09d%09d%012d", p[1], p[2], p[3], b, $2 }'; }
  [ "$(key "$1" "$2")" \> "$(key "$3" "$4")" ]
}
[ "$(uname -s)-$(uname -m)" = Darwin-arm64 ] || fail 'This release requires Apple Silicon macOS 13 or newer.'
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 13 ] || fail 'macOS 13 or newer is required.'
json() { /usr/bin/plutil -extract "$1" raw -o - "$2" 2>/dev/null; }
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null; }

# Resolve VERSION, BUILD, the download URL and its sha256 from release.json.
# Schema 2: {"schema":2,"version","build","url","sha256","notarized"}. Only a notarized stable release installs here.
resolve_release() { # resolve_release FILE -> sets VERSION BUILD URL SHA NOTARIZED
  [ "$(json schema "$1")" = 2 ] || fail 'Unsupported release.json.'
  VERSION=$(json version "$1") || fail 'release.json has no version.'
  valid_version "$VERSION" || fail 'Invalid release version.'
  BUILD=$(json build "$1") || BUILD=0
  case "$BUILD" in ''|*[!0-9]*) fail 'Invalid release build.' ;; esac
  NOTARIZED=$(json notarized "$1") || NOTARIZED=false
  # Stable is always notarized; a Beta is Developer ID signed (checked below) and may not be.
  [ "$NOTARIZED" = true ] || [ "$CHANNEL" = beta ] || fail 'The latest release is not notarized; nothing was installed.'
  URL=$(json url "$1") || fail 'release.json has no download URL.'
  [ "$URL" = "https://github.com/wandapp/app/releases/download/v$VERSION/$ASSET" ] || fail 'Unexpected download URL in release.json.'
  SHA=$(json sha256 "$1") || fail 'release.json has no checksum.'
  case "$SHA" in ''|*[!a-fA-F0-9]*) fail 'Invalid checksum in release.json.' ;; esac
  [ "${#SHA}" = 64 ] || fail 'Invalid checksum length.'
}
META=$(mktemp -d "${TMPDIR:-/tmp}/wand-release.XXXXXX")
trap 'rm -rf "$META"' EXIT HUP INT TERM
case "$RELEASE_JSON_URL" in
  https://*) curl --proto '=https' --tlsv1.2 -fLSs "$RELEASE_JSON_URL" -o "$META/release.json" || fail 'Could not read release.json.' ;;
  file://*) [ -n "${WAND_RELEASE_URL:-}" ] || fail 'Unexpected release location.'; curl -fSs "$RELEASE_JSON_URL" -o "$META/release.json" || fail 'Could not read release.json.' ;;
  *) fail 'Unexpected release location.' ;;
esac
resolve_release "$META/release.json"
rm -rf "$META"
trap - EXIT HUP INT TERM

# The App: update the copy already installed (often /Applications from the disk image), else ~/Applications.
if [ -n "${WAND_APPLICATIONS_DIR:-}" ]; then DEST=$WAND_APPLICATIONS_DIR
elif [ -d /Applications/Wand.app ] && [ -w /Applications ]; then DEST=/Applications
else DEST=$HOME/Applications; fi
case "$DEST" in /*) ;; *) fail 'Applications directory must be absolute.' ;; esac
APP_PATH=$DEST/Wand.app
# The Core runs from inside an App in an Applications folder, as the App itself installs it.
IN_PLACE=0
if [ "$DEST" = /Applications ] || [ "$DEST" = "$HOME/Applications" ]; then IN_PLACE=1; fi

# What is installed now: (version, build), empty when there is none.
INSTALLED=
if [ -d "$APP_PATH" ]; then
  [ "$(plist CFBundleIdentifier "$APP_PATH/Contents/Info.plist")" = dev.wandapp.macos ] || fail 'An unrelated Wand.app already exists; nothing replaced.'
  short=$(plist CFBundleShortVersionString "$APP_PATH/Contents/Info.plist") || short=
  pre=$(plist WandPrerelease "$APP_PATH/Contents/Info.plist") || pre=
  INSTALLED=$short${pre:+-$pre}
  INSTALLED_BUILD=$(plist CFBundleVersion "$APP_PATH/Contents/Info.plist") || INSTALLED_BUILD=0
  case "$INSTALLED_BUILD" in ''|*[!0-9]*) INSTALLED_BUILD=0 ;; esac
  valid_version "$INSTALLED" || INSTALLED=
fi
REPLACE=1
if [ -n "$INSTALLED" ] && ! newer "$VERSION" "$BUILD" "$INSTALLED" "$INSTALLED_BUILD"; then REPLACE=0; fi

if [ "${WAND_PRINT_PLAN:-}" = 1 ]; then
  printf 'channel=%s\nversion=%s\nbuild=%s\nurl=%s\nsha256=%s\napp=%s\ninstalled=%s\nreplace=%s\n' \
    "$CHANNEL" "$VERSION" "$BUILD" "$URL" "$SHA" "$APP_PATH" "${INSTALLED:-none}${INSTALLED:+ ($INSTALLED_BUILD)}" "$REPLACE"
  exit 0
fi

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

if [ "$REPLACE" = 0 ]; then
  if [ "$INSTALLED" = "$VERSION" ] && [ "$INSTALLED_BUILD" = "$BUILD" ]; then printf 'Wand %s (%s) is already installed at %s.\n' "$VERSION" "$BUILD" "$APP_PATH"
  else printf 'Wand %s (%s) at %s is newer than the published %s (%s); kept.\n' "$INSTALLED" "$INSTALLED_BUILD" "$APP_PATH" "$VERSION" "$BUILD"; fi
else
  printf 'Installing Wand %s (%s)...\n' "$VERSION" "$BUILD"
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
  [ "$(plist CFBundleIdentifier "$APP/Contents/Info.plist")" = dev.wandapp.macos ] || fail 'Unexpected application identifier.'
  [ "$(plist CFBundleShortVersionString "$APP/Contents/Info.plist")" = "${VERSION%%-*}" ] || fail 'Unexpected App version.'
  [ "$(plist CFBundleVersion "$APP/Contents/Info.plist")" = "$BUILD" ] || [ "$BUILD" = 0 ] || fail 'Unexpected App build.'
  if [ -e "$APP_PATH" ]; then
    # Never replace an executable while it is running: quit it the normal way (terminals live in the Core).
    if pgrep -f "$APP_PATH/Contents/MacOS/" >/dev/null; then
      osascript -e 'quit app id "dev.wandapp.macos"' >/dev/null 2>&1 || true
      for _ in $(seq 1 20); do pgrep -f "$APP_PATH/Contents/MacOS/" >/dev/null || break; sleep 0.5; done
      if pgrep -f "$APP_PATH/Contents/MacOS/" >/dev/null; then fail 'Wand did not quit; quit it and run this again. Nothing was changed.'; fi
    fi
    BACKUP=$DEST/Wand.previous.$(date +%Y%m%d%H%M%S).app
    [ ! -e "$BACKUP" ] || fail 'A backup with this timestamp already exists; retry shortly.'
    mv "$APP_PATH" "$BACKUP"
    if ! mv "$APP" "$APP_PATH"; then mv "$BACKUP" "$APP_PATH"; fail 'Installation failed; previous App restored.'; fi
    # Keep only the newest backup, as the App's own updater does.
    last=
    for old in "$DEST"/Wand.previous.*.app; do [ -e "$old" ] || continue; [ -z "$last" ] || rm -rf "$last"; last=$old; done
  else
    mv "$APP" "$APP_PATH"
  fi
  printf 'Installed %s.\n' "$APP_PATH"
fi

# The update source from now on: the official feed of this channel, for the App and the Core alike.
CORE_HOME="$HOME/Library/Application Support/Wand/core"
mkdir -p "$CORE_HOME/state" && printf '%s' "$CHANNEL" > "$CORE_HOME/state/channel"
rm -f "$CORE_HOME/state/peer"
defaults write dev.wandapp.macos wand.beta -bool "$([ "$CHANNEL" = beta ] && echo true || echo false)"
defaults delete dev.wandapp.macos wand.appSource >/dev/null 2>&1 || true

# The Core: the one this App carries, with every module on it.
BUNDLE=$APP_PATH/Contents/Resources/wand-core
BIN=$APP_PATH/Contents/Helpers/wand-core/bin
[ -f "$BUNDLE/install.sh" ] && [ -x "$BIN/gatewayd" ] || fail "$APP_PATH carries no Core; nothing else was changed."
CORE_VERSION=$(tr -d ' \r\n' < "$BUNDLE/VERSION")
CORE_BUILD=$(json build "$BUNDLE/build.json") || CORE_BUILD=0
CORE_DATA=$(json data "$CORE_HOME/install.json") || CORE_DATA="$HOME/.wand-core"
PORT=$(json port "$CORE_DATA/network.json") || PORT=3210
case "$PORT" in ''|*[!0-9]*) PORT=3210 ;; esac
RECORD=$CORE_HOME/state/restart-terminal
hello() { curl -fsS -m 2 "http://127.0.0.1:$PORT/v1/hello" -o "$TEMP/hello.json" 2>/dev/null; }
# on_build: the gateway answers on the App's Core build, and the terminal service is not behind it.
on_build() {
  hello && [ "$(json version "$TEMP/hello.json")" = "$CORE_VERSION" ] && [ "$(json build "$TEMP/hello.json")" = "$CORE_BUILD" ] \
    && [ "$(json restartPending "$TEMP/hello.json")" != true ]
}
LINKED=$(json bin "$CORE_HOME/install.json") || LINKED=
if [ "$IN_PLACE" = 1 ] && [ "$LINKED" = "$(cd "$BIN" && pwd -P)" ] && on_build && [ ! -e "$RECORD" ]; then
  printf 'Wand Core %s (%s) is running from the App, terminal service included.\n' "$CORE_VERSION" "$CORE_BUILD"
else
  set -- --port "$PORT" --instance core
  if [ "$IN_PLACE" = 1 ]; then
    SOURCE=$BUNDLE
    set -- "$@" --bin "$BIN" --link --updates external --associate dev.wandapp.macos
  else
    # A copy outside an Applications folder installs a copy of its Core, without the download quarantine.
    mkdir "$TEMP/core" && cp -R "$BUNDLE" "$TEMP/core/wand-core" && cp -R "$BIN" "$TEMP/core/bin"
    xattr -dr com.apple.quarantine "$TEMP/core" 2>/dev/null || true
    SOURCE=$TEMP/core/wand-core
    set -- "$@" --bin "$TEMP/core/bin"
  fi
  FULL=0
  grep -q -- '--restart-terminal)' "$SOURCE/install.sh" && { FULL=1; set -- "$@" --restart-terminal; }
  printf 'Updating Wand Core to %s (%s) on port %s, terminal service included...\n' "$CORE_VERSION" "$CORE_BUILD" "$PORT"
  sh "$SOURCE/install.sh" "$@" </dev/null || fail "Wand Core installation failed; see $CORE_DATA/gatewayd.log."
  # The new gateway restarts the terminal service as soon as it is up and drops the record once it has.
  UP=0
  for _ in $(seq 1 120); do
    if on_build && { [ "$FULL" = 0 ] || [ ! -e "$RECORD" ]; }; then UP=1; break; fi
    sleep 1
  done
  if [ "$UP" = 0 ]; then
    if hello && [ "$(json version "$TEMP/hello.json")" = "$CORE_VERSION" ] && [ "$FULL" = 0 ]; then
      printf 'Wand Core %s is running; its terminal service moves over at its next restart (this App predates restarting it here).\n' "$CORE_VERSION"
    else
      fail "Wand Core $CORE_VERSION ($CORE_BUILD) was installed but did not come up completely on port $PORT within 2 minutes; see $CORE_DATA/gatewayd.log and $CORE_DATA/sessiond.log."
    fi
  else
    printf 'Wand Core %s (%s) is running, terminal service included; running terminals were restored.\n' "$CORE_VERSION" "$CORE_BUILD"
  fi
fi

open "$APP_PATH"
printf 'Opened %s. Login startup and background services are registered by the App.\n' "$APP_PATH"
printf 'If macOS requests background-item approval, complete the system prompt in Wand.\n'

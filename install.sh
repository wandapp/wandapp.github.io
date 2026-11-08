#!/bin/sh
# Installs a verified, versioned Core bundle. Never starts or restarts services.
set -eu
VERSION=0.1.0
RELEASE=https://github.com/wandapp/wandapp.github.io/releases/download/core-v$VERSION
ASSET=wand-core-darwin-arm64.tar.gz
fail() { printf '%s\n' "$*" >&2; exit 1; }
[ "$(uname -s)-$(uname -m)" = Darwin-arm64 ] || fail 'This release supports Apple Silicon macOS. Other platforms are not available yet.'
for command in curl tar shasum mktemp; do command -v "$command" >/dev/null || fail "Missing required tool: $command"; done
ROOT=${WAND_INSTALL_ROOT:-$HOME/.local/share/wand-core}
BIN=${WAND_BIN_DIR:-$HOME/.local/bin}
case "$ROOT:$BIN" in /*:/*) ;; *) fail 'Installation directories must be absolute paths.' ;; esac
if [ -e "$BIN/wand-core" ] || [ -L "$BIN/wand-core" ]; then
  [ -L "$BIN/wand-core" ] && [ "$(readlink "$BIN/wand-core")" = "$ROOT/current/wand-core" ] || fail "Existing $BIN/wand-core is not managed by this installer."
fi
if [ -e "$ROOT/current" ] && [ ! -L "$ROOT/current" ]; then
  fail "Existing $ROOT/current is not a managed symlink."
fi
umask 077
mkdir -p "$ROOT/versions" "$BIN"
LOCK=$ROOT/install.lock
mkdir "$LOCK" 2>/dev/null || fail "Another installation is active (or left a lock): $LOCK"
TEMP=$(mktemp -d "$ROOT/download.XXXXXX")
cleanup() { rm -rf "$TEMP"; rmdir "$LOCK"; }
trap cleanup EXIT HUP INT TERM
printf 'Downloading Wand Core %s…\n' "$VERSION"
curl --proto '=https' --tlsv1.2 -fLSs "$RELEASE/$ASSET" -o "$TEMP/$ASSET"
curl --proto '=https' --tlsv1.2 -fLSs "$RELEASE/$ASSET.sha256" -o "$TEMP/checksum"
HASH=$(awk -v file="$ASSET" '$2 == file && length($1) == 64 { print $1 }' "$TEMP/checksum")
case "$HASH" in ''|*[!a-fA-F0-9]*) fail 'Invalid checksum manifest.' ;; esac
[ "${#HASH}" = 64 ] || fail 'Invalid checksum length.'
printf '%s  %s\n' "$HASH" "$TEMP/$ASSET" | shasum -a 256 -c -
tar -tzf "$TEMP/$ASSET" > "$TEMP/entries"
awk '/^\// || /(^|\/)\.\.($|\/)/ || !/^wand-core(\/|$)/ { bad=1 } END { exit bad }' "$TEMP/entries" || fail 'Unsafe archive paths.'
tar -xzf "$TEMP/$ASSET" -C "$TEMP"
BUNDLE=$TEMP/wand-core
[ "$(cat "$BUNDLE/VERSION")" = "$VERSION" ] || fail 'Bundle version mismatch.'
"$BUNDLE/wand-core" check
DEST=$ROOT/versions/$VERSION
if [ -e "$DEST" ]; then
  [ -f "$DEST/.archive-sha256" ] && [ "$(cat "$DEST/.archive-sha256")" = "$HASH" ] || fail 'This version already exists with different content. Existing installation preserved.'
else
  printf '%s\n' "$HASH" > "$BUNDLE/.archive-sha256"
  mv "$BUNDLE" "$DEST"
fi
# macOS mv -h replaces the link itself, never its target directory.
ln -s "versions/$VERSION" "$TEMP/current"
mv -fh "$TEMP/current" "$ROOT/current"
if [ -e "$BIN/wand-core" ] && [ ! -L "$BIN/wand-core" ]; then
  fail "A non-symlink already exists at $BIN/wand-core; it was not replaced."
fi
ln -s "$ROOT/current/wand-core" "$TEMP/command"
mv -fh "$TEMP/command" "$BIN/wand-core"
printf '\nInstalled Wand Core %s. No service was restarted.\n' "$VERSION"
printf 'Start: "%s/wand-core" start\n' "$BIN"
printf 'Without Web: "%s/wand-core" start --no-web\n' "$BIN"
printf 'Existing terminal sessions keep running on their original Scheduler.\n'

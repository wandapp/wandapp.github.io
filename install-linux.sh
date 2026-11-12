#!/bin/sh
# Install Wand Core (sessiond + gatewayd + updater) as systemd services under /opt/wand-core.
# The signed update feed cannot be verified before the first install: the trust key ships inside
# the bundle. This script therefore relies on HTTPS plus the sha256 and size in the feed; later
# updates are verified by the installed updater against the pinned key.
# --beta installs the newest build, stable or Beta, and keeps the Core on the Beta channel; without it, stable.
# Either way the update source becomes the official feed (a host this one followed is forgotten), and the run ends
# only when every module answers on the new build: the gateway and web client by restarting the gateway, the
# terminal service by restarting it too (running terminals are interrupted and restored in their directories).
# Environment: WAND_PORT (default: the existing install's port, else 3210), WAND_SERVICE_USER (default: the invoking user).
# Tests only: WAND_MANIFEST_URL overrides the feed (file:// is accepted only through it),
# WAND_PLATFORM picks the artifact, WAND_PRINT_PLAN=1 prints the resolved plan and exits.
set -eu
fail() { printf '%s\n' "$*" >&2; exit 1; }
CHANNEL=stable
for arg in "$@"; do
  case "$arg" in
    --beta) CHANNEL=beta ;;
    *) fail "Unknown option: $arg (only --beta is supported)" ;;
  esac
done
if [ "$CHANNEL" = beta ]; then MANIFEST_URL=${WAND_MANIFEST_URL:-https://github.com/wandapp/core/releases/download/beta/manifest.json}
else MANIFEST_URL=${WAND_MANIFEST_URL:-https://github.com/wandapp/core/releases/latest/download/manifest.json}; fi
RELEASE_PREFIX=https://github.com/wandapp/core/releases/download/v

# json_field FLAT_JSON KEY KIND -> value of the first KEY (KIND: string|number)
json_field() {
  if [ "$3" = number ]; then
    printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p"
  else
    printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
  fi
}

# resolve_artifact MANIFEST_FILE PLATFORM -> sets ART_URL ART_SHA ART_SIZE or fails
resolve_artifact() {
  flat=$(tr -d '\n\r' < "$1")
  core=$(printf '%s' "$flat" | sed -n 's/.*"core"[[:space:]]*:[[:space:]]*{\(.*\)}[[:space:]]*,[[:space:]]*"issued".*/\1/p')
  [ -n "$core" ] || core=$(printf '%s' "$flat" | sed -n 's/.*"core"[[:space:]]*:[[:space:]]*{\(.*\)/\1/p')
  entry=$(printf '%s' "$core" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*{\\([^}]*\\)}.*/\\1/p")
  [ -n "$entry" ] || fail "Wand Core is not published for $2 yet; nothing was installed."
  ART_URL=$(json_field "$entry" url string)
  ART_SHA=$(json_field "$entry" sha256 string)
  ART_SIZE=$(json_field "$entry" size number)
  case "$ART_SHA" in ''|*[!0-9a-fA-F]*) fail 'Invalid checksum in the release feed.' ;; esac
  [ "${#ART_SHA}" = 64 ] || fail 'Invalid checksum length in the release feed.'
  [ -n "$ART_SIZE" ] || fail 'Invalid size in the release feed.'
  name=${ART_URL##*/}
  ver=${name#wand-core-}; ver=${ver%-"$2".tar.gz}
  printf '%s' "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$' || fail 'Unexpected download URL in the release feed.'
  [ "$ART_URL" = "$RELEASE_PREFIX$ver/wand-core-$ver-$2.tar.gz" ] || fail 'Unexpected download URL in the release feed.'
}

fetch_manifest() { # fetch_manifest DEST
  case "$MANIFEST_URL" in
    https://*) curl --proto '=https' --tlsv1.2 -fLSs "$MANIFEST_URL" -o "$1" || fail 'Could not read the release feed.' ;;
    file://*) [ -n "${WAND_MANIFEST_URL:-}" ] || fail 'Unexpected release feed location.'
      curl -fSs "$MANIFEST_URL" -o "$1" || fail 'Could not read the release feed.' ;;
    *) fail 'Unexpected release feed location.' ;;
  esac
}

case "$(uname -m)" in aarch64|arm64) ARCH=arm64 ;; x86_64|amd64) ARCH=x64 ;; *) ARCH= ;; esac
PLATFORM=${WAND_PLATFORM:-linux-$ARCH}

if [ "${WAND_PRINT_PLAN:-}" = 1 ]; then
  command -v curl >/dev/null || fail 'curl is required.'
  PLAN=$(mktemp -d "${TMPDIR:-/tmp}/wand-plan.XXXXXX")
  trap 'rm -rf "$PLAN"' EXIT HUP INT TERM
  fetch_manifest "$PLAN/manifest.json"
  resolve_artifact "$PLAN/manifest.json" "$PLATFORM"
  printf 'channel=%s\nplatform=%s\nurl=%s\nsha256=%s\nsize=%s\n' "$CHANNEL" "$PLATFORM" "$ART_URL" "$ART_SHA" "$ART_SIZE"
  exit 0
fi

[ "$(uname -s)" = Linux ] || fail 'Linux is required.'
[ -n "$ARCH" ] || fail 'Unsupported CPU architecture.'
# Fail before privilege escalation, account creation or installation mutations.
GLIBC=$(getconf GNU_LIBC_VERSION 2>/dev/null) || fail 'Wand requires glibc 2.36 or newer; musl systems are unsupported.'
printf '%s\n' "$GLIBC" | awk '$1 == "glibc" { split($2,v,"."); if (v[1] > 2 || (v[1] == 2 && v[2] >= 36)) ok=1 } END {exit !ok}' || fail "Wand requires glibc 2.36 or newer (found: $GLIBC)."
[ -d /run/systemd/system ] || fail 'This installer requires a booted systemd host.'
# The unified entry downloads this file before invoking it, so sudo never consumes
# a pipe containing the installer as password input. Everything below runs as root,
# so the downloaded bundle is never writable by a normal user while it is installed.
if [ "$(id -u)" != 0 ]; then
  command -v sudo >/dev/null || fail 'sudo is required for system service installation.'
  [ -f "$0" ] || fail 'Save this installer to a file before invoking it directly.'
  exec sudo env "WAND_SERVICE_USER=${WAND_SERVICE_USER:-$(id -un)}" "WAND_PORT=${WAND_PORT:-}" "WAND_MANIFEST_URL=${WAND_MANIFEST_URL:-}" sh "$0" "$@"
fi
USER_NAME=${WAND_SERVICE_USER:-${SUDO_USER:-}}
case "$USER_NAME" in root|*[!a-zA-Z0-9_-]*) fail 'A non-root service user is required.' ;; esac
PORT=${WAND_PORT:-}
case "$PORT" in *[!0-9]*) fail 'WAND_PORT must be a number.' ;; esac
# Upgrading keeps the port the existing install uses (the web UI can change it in network.json).
if [ -z "$PORT" ] && [ -f /opt/wand-core/install.json ]; then
  OLD=$(tr -d '\n\r' < /opt/wand-core/install.json)
  OLD_DATA=$(json_field "$OLD" data string)
  [ -z "$OLD_DATA" ] || [ ! -f "$OLD_DATA/network.json" ] || PORT=$(json_field "$(tr -d '\n\r' < "$OLD_DATA/network.json")" port number)
  [ -n "$PORT" ] || PORT=$(json_field "$OLD" port number)
fi
for command in curl tar awk sed tr wc systemctl; do command -v "$command" >/dev/null || fail "Missing required command: $command"; done
if command -v sha256sum >/dev/null; then sha() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null; then sha() { shasum -a 256 "$1" | awk '{print $1}'; }
else fail 'Missing required command: sha256sum'; fi

TEMP=$(mktemp -d "${TMPDIR:-/tmp}/wand-install.XXXXXX")
trap 'rm -rf "$TEMP"' EXIT HUP INT TERM
fetch_manifest "$TEMP/manifest.json"
resolve_artifact "$TEMP/manifest.json" "$PLATFORM"

ARCHIVE=$TEMP/core.tar.gz
curl --proto '=https' --tlsv1.2 -fLSs "$ART_URL" -o "$ARCHIVE" || fail 'Could not download Wand Core.'
[ "$(wc -c < "$ARCHIVE" | tr -d ' ')" = "$ART_SIZE" ] || fail 'Downloaded size does not match the release feed.'
[ "$(sha "$ARCHIVE")" = "$(printf '%s' "$ART_SHA" | tr 'A-F' 'a-f')" ] || fail 'Checksum mismatch; nothing was installed.'
tar -tzf "$ARCHIVE" > "$TEMP/entries" || fail 'Unreadable archive.'
awk '/^\// || /(^|\/)\.\.($|\/)/ || !/^(\.\/)?wand-core(\/|$)/ {bad=1} END {exit bad}' "$TEMP/entries" || fail 'Unsafe archive paths.'
mkdir "$TEMP/extract"
tar -xzf "$ARCHIVE" -C "$TEMP/extract" --no-same-owner
BUNDLE=$TEMP/extract/wand-core
[ -f "$BUNDLE/install.sh" ] && [ -d "$BUNDLE/bin" ] || fail 'Unexpected bundle layout; nothing was installed.'

if [ -e /opt/wand/current ] || systemctl list-unit-files wand-scheduler.service 2>/dev/null | grep -q wand-scheduler; then
  printf '%s\n' 'An older Wand install (wand-scheduler / wand-server) is left as is; both default to port 3210, so stop the old services first or set WAND_PORT to another port.'
fi

set -- --prefix /opt/wand-core
[ -z "$USER_NAME" ] || set -- "$@" --user "$USER_NAME"
[ -z "$PORT" ] || set -- "$@" --port "$PORT"
FULL=0
grep -q -- '--restart-terminal)' "$BUNDLE/install.sh" && { FULL=1; set -- "$@" --restart-terminal; }
# Piped installs (curl | sh) have no terminal on stdin; the first-account prompt reads the controlling terminal.
if [ ! -t 0 ] && ( : </dev/tty ) 2>/dev/null; then sh "$BUNDLE/install.sh" "$@" </dev/tty
else sh "$BUNDLE/install.sh" "$@"; fi
# The channel later updates follow; the updater runs as the service user, which owns state/.
printf '%s' "$CHANNEL" > /opt/wand-core/state/channel
[ -z "$USER_NAME" ] || chown "$USER_NAME": /opt/wand-core/state/channel
rm -f /opt/wand-core/state/peer

# Every module on the new build: the gateway answers on it and the terminal service is no longer behind
# (the new gateway restarts it as soon as it is up and drops the record once it has).
VERSION=$(tr -d ' \r\n' < "$BUNDLE/VERSION")
BUILD=$(json_field "$(tr -d '\n\r' < "$BUNDLE/build.json" 2>/dev/null)" build number)
LISTEN=${PORT:-3210}
RECORD=/opt/wand-core/state/restart-terminal
on_build() {
  hello=$(curl -fsS -m 2 "http://127.0.0.1:$LISTEN/v1/hello" 2>/dev/null) || return 1
  [ "$(json_field "$hello" version string)" = "$VERSION" ] && [ "$(json_field "$hello" build number)" = "${BUILD:-0}" ] \
    && ! printf '%s' "$hello" | grep -q '"restartPending"[[:space:]]*:[[:space:]]*true' && { [ "$FULL" = 0 ] || [ ! -e "$RECORD" ]; }
}
UP=0
for _ in $(seq 1 120); do
  if on_build; then UP=1; break; fi
  sleep 1
done
[ "$UP" = 1 ] || fail "Wand Core $VERSION was installed but did not come up completely on port $LISTEN within 2 minutes; see journalctl -u wand-core-gatewayd -u wand-core-sessiond."
printf 'Wand Core %s (%s) is running on port %s, terminal service included.\n' "$VERSION" "${BUILD:-0}" "$LISTEN"

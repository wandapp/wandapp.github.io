#!/bin/sh
# System installation; Scheduler and gateway retain independent lifecycles.
set -eu
VERSION=0.1.1
RELEASE=https://github.com/wandapp/wandapp.github.io/releases/download/core-v$VERSION
fail() { printf '%s\n' "$*" >&2; exit 1; }
[ "$(uname -s)" = Linux ] || fail 'Linux is required.'
case "$(uname -m)" in aarch64|arm64) ARCH=arm64 ;; x86_64|amd64) ARCH=x64 ;; *) fail 'Unsupported CPU architecture.' ;; esac
# Fail before privilege escalation, account creation or installation mutations.
GLIBC=$(getconf GNU_LIBC_VERSION 2>/dev/null) || fail 'Wand requires glibc 2.36 or newer; musl systems are unsupported.'
printf '%s\n' "$GLIBC" | awk '$1 == "glibc" { split($2,v,"."); if (v[1] > 2 || (v[1] == 2 && v[2] >= 36)) ok=1 } END {exit !ok}' || fail "Wand requires glibc 2.36 or newer (found: $GLIBC)."
# The unified entry downloads this file before invoking it, so sudo never consumes
# a pipe containing the installer as password input.
if [ "$(id -u)" != 0 ]; then
  command -v sudo >/dev/null || fail 'sudo is required for system service installation.'
  [ -f "$0" ] || fail 'Save this installer to a file before invoking it directly.'
  USER_NAME=$(id -un)
  exec sudo sh "$0" --service-user "$USER_NAME"
fi
USER_NAME=${WAND_SERVICE_USER:-${SUDO_USER:-wand}}
if [ "${1:-}" = --service-user ]; then USER_NAME=${2:?Missing service user}; fi
case "$USER_NAME" in ''|root|*[!a-zA-Z0-9_-]*) fail 'A non-root service user is required.' ;; esac
[ -d /run/systemd/system ] || fail 'This installer requires a booted systemd host.'
for command in curl tar sha256sum systemctl getent runuser; do command -v "$command" >/dev/null || fail "Missing required command: $command"; done
# Prefix permits package validation in a disposable filesystem; production is /opt.
ROOT=${WAND_LINUX_INSTALL_ROOT:-/opt/wand}
UNITS=${WAND_SYSTEMD_UNIT_DIR:-/etc/systemd/system}
case "$ROOT:$UNITS" in *[!a-zA-Z0-9_./:-]*) fail 'Invalid installation directory.' ;; /*:/*) ;; *) fail 'Installation directories must be absolute.' ;; esac
umask 022
mkdir -p "$ROOT/versions" "$UNITS"
LOCK=$ROOT/install.lock
mkdir "$LOCK" 2>/dev/null || fail "Another installation is active: $LOCK"
TEMP=$(mktemp -d "$ROOT/download.XXXXXX")
cleanup() { rm -rf "$TEMP"; rmdir "$LOCK"; }
trap cleanup EXIT HUP INT TERM
ASSET=wand-core-linux-$ARCH.tar.gz
curl --proto '=https' --tlsv1.2 -fLSs "$RELEASE/$ASSET" -o "$TEMP/$ASSET"
curl --proto '=https' --tlsv1.2 -fLSs "$RELEASE/$ASSET.sha256" -o "$TEMP/checksum"
HASH=$(awk -v file="$ASSET" '$2 == file && length($1)==64 {print $1}' "$TEMP/checksum")
case "$HASH" in ''|*[!a-fA-F0-9]*) fail 'Invalid checksum manifest.' ;; esac
[ "${#HASH}" = 64 ] || fail 'Invalid checksum length.'
printf '%s  %s\n' "$HASH" "$TEMP/$ASSET" | sha256sum -c -
tar -tzf "$TEMP/$ASSET" > "$TEMP/entries"
awk '/^\// || /(^|\/)\.\.($|\/)/ || !/^wand-core(\/|$)/ {bad=1} END {exit bad}' "$TEMP/entries" || fail 'Unsafe archive paths.'
tar -xzf "$TEMP/$ASSET" -C "$TEMP" --no-same-owner
BUNDLE=$TEMP/wand-core
[ "$(cat "$BUNDLE/VERSION")" = "$VERSION" ] || fail 'Bundle version mismatch.'
"$BUNDLE/bin/wand-scheduler" --check-runtime
if ! id "$USER_NAME" >/dev/null 2>&1; then
  [ "$USER_NAME" = wand ] || fail 'Requested service user does not exist.'
  useradd --system --create-home --home-dir /var/lib/wand --shell /bin/bash wand
fi
[ "$(id -u "$USER_NAME")" != 0 ] || fail 'Service account must not have UID 0.'
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
USER_GROUP=$(id -gn "$USER_NAME")
case "$USER_HOME" in /*) ;; *) fail 'Service home must be absolute.' ;; esac
case "$USER_HOME" in *[!a-zA-Z0-9_./-]*) fail 'Service home contains unsupported systemd characters.' ;; esac
DEST=$ROOT/versions/$VERSION-$ARCH
if [ -e "$DEST" ]; then
  [ -f "$DEST/.archive-sha256" ] && [ "$(cat "$DEST/.archive-sha256")" = "$HASH" ] || fail 'Existing version content differs; nothing replaced.'
else
  printf '%s\n' "$HASH" > "$BUNDLE/.archive-sha256"
  mv "$BUNDLE" "$DEST"
fi
# Refuse to adopt an unmanaged running scheduler or gateway. Updates keep existing
# services on their old version; systemd does not restart active units on start.
for unit in wand-scheduler.service wand-server.service; do
  if [ -f "$UNITS/$unit" ] && ! head -1 "$UNITS/$unit" | grep -qx '# Managed by Wand installer'; then
    fail "Unmanaged system service $unit exists; it was not overwritten."
  fi
done
if [ -S "$USER_HOME/.new-wand/scheduler.sock" ] && ! systemctl is-active --quiet wand-scheduler.service; then
  fail 'An unmanaged Scheduler exists. Existing sessions were preserved; migrate after draining them.'
fi
install -d -m 0700 -o "$USER_NAME" -g "$USER_GROUP" "$USER_HOME/.new-wand"
if [ -e "$ROOT/current" ] && [ ! -L "$ROOT/current" ]; then fail 'Current path is not a managed symlink.'; fi
ln -s "versions/$VERSION-$ARCH" "$TEMP/current"
mv -Tf "$TEMP/current" "$ROOT/current"
cat > "$TEMP/wand-scheduler.service" <<UNIT
# Managed by Wand installer
[Unit]
Description=Wand terminal scheduler
After=network.target
[Service]
Type=exec
User=$USER_NAME
Group=$USER_GROUP
Environment=HOME=$USER_HOME
Environment=SHELL=/bin/bash
Environment=WAND_SCHEDULER_DIR=$USER_HOME/.new-wand
WorkingDirectory=$USER_HOME
ExecStart=$DEST/bin/wand-scheduler
Restart=on-failure
RestartSec=3
UMask=0077
[Install]
WantedBy=multi-user.target
UNIT
cat > "$TEMP/wand-server.service" <<UNIT
# Managed by Wand installer
[Unit]
Description=Wand HTTP and WebSocket gateway
Wants=wand-scheduler.service
After=network.target wand-scheduler.service
[Service]
Type=exec
User=$USER_NAME
Group=$USER_GROUP
Environment=HOME=$USER_HOME
Environment=WAND_SCHEDULER_DIR=$USER_HOME/.new-wand
Environment=FRONTEND_DIST=$DEST/web
WorkingDirectory=$USER_HOME
ExecStart=$DEST/bin/wand-server
Restart=on-failure
RestartSec=3
UMask=0077
[Install]
WantedBy=multi-user.target
UNIT
install -m 0644 "$TEMP/wand-scheduler.service" "$UNITS/wand-scheduler.service"
install -m 0644 "$TEMP/wand-server.service" "$UNITS/wand-server.service"
systemctl daemon-reload
systemctl enable --now wand-scheduler.service wand-server.service
systemctl is-enabled --quiet wand-scheduler.service
systemctl is-enabled --quiet wand-server.service
# Type=exec guarantees exec succeeded; check the gateway actually became healthy.
attempt=0
until curl -fSs --max-time 2 http://127.0.0.1:3210/api/health > "$TEMP/health"; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 15 ] || fail 'Installed services did not become healthy; inspect journalctl -u wand-server.'
  sleep 1
done
systemctl is-active --quiet wand-scheduler.service
systemctl is-active --quiet wand-server.service
printf 'Wand is installed and enabled at boot for user %s.\n' "$USER_NAME"
# Initial setup runs against loopback on this host; SSH forwarding is unnecessary.
setup_status=0
"$DEST/wand-core" setup --check || setup_status=$?
case "$setup_status" in
  0) ;;
  2)
    if ( : </dev/tty ) 2>/dev/null; then
      "$DEST/wand-core" setup </dev/tty
    else
      printf 'Services are running; account setup is still required.\n'
      printf 'From an interactive SSH terminal run: %s/wand-core setup\n' "$DEST"
    fi
    ;;
  *) fail 'Unable to check account setup; inspect the running gateway.' ;;
esac
printf 'Open this server’s LAN address on port 3210 in a browser.\n' 
printf 'Existing running services are not restarted by updates. Installed version: %s.\n' "$VERSION"

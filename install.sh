#!/bin/sh
# One installation entry: desktop App on macOS, system services on Linux.
set -eu
main() {
  case "$(uname -s)" in
    Darwin) installer=install-macos.sh ;;
    Linux) installer=install-linux.sh ;;
    *) echo 'Wand currently supports macOS and Linux installation.' >&2; return 1 ;;
  esac
  command -v curl >/dev/null || { echo 'curl is required.' >&2; return 1; }
  umask 077
  script=$(mktemp "${TMPDIR:-/tmp}/wand-install.XXXXXX")
  trap 'rm -f "$script"' EXIT HUP INT TERM
  curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error "https://wandapp.github.io/$installer" -o "$script"
  sh "$script"
}
main "$@"

#!/bin/sh
# Compile the bootstrap TLS-key shim and exercise its 1024-slot table.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="${GENESIS_WORK:-$ROOT/.work}/tmp"
mkdir -p "$WORK"
TMP="$(mktemp -d "$WORK/tls-shim.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM

cc -shared -fPIC -O2 -o "$TMP/tlskeys.so" "$ROOT/support/tlskeys.c" -ldl
cc -O2 -pthread -o "$TMP/tlskeys_test" "$HERE/tlskeys_test.c"

if "$TMP/tlskeys_test" >"$TMP/plain.log" 2>&1; then
  echo "note: host musl allows the full key table without the shim"
else
  :
fi

out="$(LD_PRELOAD="$TMP/tlskeys.so" "$TMP/tlskeys_test")"
echo "$out"
echo "$out" | grep -q "tls-shim ok" || { echo "FAIL: shim test" >&2; exit 1; }
echo "TLS_SHIM_OK"

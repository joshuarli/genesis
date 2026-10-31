#!/bin/sh
# Build the pinned rustfilt 0.2.1 external CLI with the selected toolchain.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PREFIX=""
WORK_DIR=""
PREPARE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:-}"; shift 2 ;;
    --work-dir) WORK_DIR="${2:-}"; shift 2 ;;
    --prepare) PREPARE=1; shift ;;
    -h|--help)
      echo "usage: tests/external/run.sh --prefix <toolchain-prefix> [--work-dir DIR] [--prepare]"
      exit 0
      ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$PREFIX" ] || { echo "missing --prefix" >&2; exit 2; }
[ -d "$PREFIX" ] || { echo "no toolchain prefix: $PREFIX" >&2; exit 1; }
PREFIX="$(cd "$PREFIX" && pwd)"
[ -x "$PREFIX/bin/rustc" ] || { echo "no rustc in $PREFIX" >&2; exit 1; }
[ -x "$PREFIX/bin/cargo" ] || { echo "no cargo in $PREFIX" >&2; exit 1; }

HOST="$("$PREFIX/bin/rustc" -vV | sed -n 's/^host: //p' | head -n1)"
SYSROOT="$("$PREFIX/bin/rustc" --print sysroot)"
SYSROOT_LIB="$SYSROOT/lib/rustlib/$HOST/lib"
[ -d "$SYSROOT_LIB" ] || { echo "missing sysroot lib: $SYSROOT_LIB" >&2; exit 1; }
WORK="${GENESIS_WORK:-$ROOT/.work}"
BASE="${WORK_DIR:-$WORK/tests/external}"
mkdir -p "$BASE"
BASE="$(cd "$BASE" && pwd)"
PKG="$BASE/rustfilt-0.2.1"
CARGO_HOME_DIR="$BASE/cargo-home"
mkdir -p "$PKG" "$CARGO_HOME_DIR"
cp -R "$HERE/rustfilt-0.2.1/." "$PKG/"

export PATH="$PREFIX/bin:/usr/bin:/bin"
export RUSTC="$PREFIX/bin/rustc"
export CARGO="$PREFIX/bin/cargo"
export CARGO_HOME="$CARGO_HOME_DIR"
export RUSTC_WRAPPER=
export RUSTC_WORKSPACE_WRAPPER=
export CC=cc CXX=c++ HOST_CC=cc HOST_CXX=c++
export LD_LIBRARY_PATH="$SYSROOT_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

prepare_vendor() {
  if [ -d "$PKG/vendor" ] && [ "$PREPARE" = "0" ]; then
    write_vendor_config
    return 0
  fi
  rm -rf "$PKG/vendor"
  mkdir -p "$PKG/.cargo"
  echo "external: fetching pinned crates with cargo vendor"
  if ! (cd "$PKG" && CARGO_NET_OFFLINE=false "$PREFIX/bin/cargo" vendor --locked vendor) >"$BASE/vendor.log" 2>&1; then
    echo "FAIL: cargo vendor failed; network access to crates.io is required once" >&2
    cat "$BASE/vendor.log" >&2
    exit 1
  fi
  write_vendor_config
}

write_vendor_config() {
  mkdir -p "$PKG/.cargo"
  cat > "$PKG/.cargo/config.toml" <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOF
}

prepare_vendor
if [ "$PREPARE" = "1" ]; then
  echo "EXTERNAL_PREPARE_OK rustfilt-0.2.1"
  exit 0
fi

export CARGO_NET_OFFLINE=true
log="$BASE/build.log"
if (cd "$PKG" && "$PREFIX/bin/cargo" build --offline --release --config 'profile.release.lto=false') >"$log" 2>&1; then
  tail -n 2 "$log"
else
  rc=$?
  echo "FAIL: rustfilt build failed (exit $rc)" >&2
  cat "$log" >&2
  exit "$rc"
fi
exe="$PKG/target/release/rustfilt"
[ -x "$exe" ] || { echo "FAIL: rustfilt executable missing: $exe" >&2; exit 1; }
echo "_ZN3foo3barE" | "$exe" | grep -q "foo::bar" || { echo "FAIL: demangle check" >&2; exit 1; }
echo "EXTERNAL_OK rustfilt-0.2.1"

#!/bin/sh
# Run Rust usability fixtures with the selected toolchain only.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PREFIX=""
WORK_DIR=""
ONLY=""
KEEP=0
STATIC=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:-}"; shift 2 ;;
    --work-dir) WORK_DIR="${2:-}"; shift 2 ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    --static) STATIC=1; shift ;;
    -h|--help)
      echo "usage: tests/smoke/run.sh --prefix <toolchain-prefix> [--work-dir DIR] [--only case,...] [--keep] [--static]"
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
[ -n "$HOST" ] || { echo "cannot determine host from $PREFIX/bin/rustc" >&2; exit 1; }
SYSROOT="$("$PREFIX/bin/rustc" --print sysroot)"
SYSROOT_LIB="$SYSROOT/lib/rustlib/$HOST/lib"
[ -d "$SYSROOT_LIB" ] || { echo "missing sysroot lib: $SYSROOT_LIB" >&2; exit 1; }
WORK="${GENESIS_WORK:-$ROOT/.work}"
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"

export PATH="$PREFIX/bin:/usr/bin:/bin"
export RUSTC="$PREFIX/bin/rustc"
export RUSTDOC="$PREFIX/bin/rustdoc"
export CARGO="$PREFIX/bin/cargo"
export CARGO_NET_OFFLINE=true
export CARGO_HOME="$WORK/cargo-home"
export LD_LIBRARY_PATH="$SYSROOT_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export RUSTC_WRAPPER=
export RUSTC_WORKSPACE_WRAPPER=

cleanup() {
  if [ "$KEEP" = "0" ] && [ -n "${TMP_ROOT:-}" ]; then
    rm -rf "$TMP_ROOT"
  fi
}
trap cleanup EXIT INT TERM

if [ -n "$WORK_DIR" ]; then
  TMP_ROOT="$WORK_DIR"
  mkdir -p "$TMP_ROOT"
  TMP_ROOT="$(cd "$TMP_ROOT" && pwd)"
else
  TMP_BASE="$WORK/tmp"
  mkdir -p "$TMP_BASE"
  TMP_ROOT="$(mktemp -d "$TMP_BASE/smoke.XXXXXX")"
fi
export CARGO_TARGET_DIR="$TMP_ROOT/target"
mkdir -p "$CARGO_TARGET_DIR"

selected() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass=0
run_case() {
  name="$1"
  dir="$2"
  bin="$3"
  expect="$4"
  selected "$name" || return 0
  echo "--- $name ---"
  log="$TMP_ROOT/$name-build.log"
  if (cd "$dir" && "$PREFIX/bin/cargo" build --offline --release) >"$log" 2>&1; then
    tail -n 2 "$log"
  else
    rc=$?
    echo "FAIL: $name build failed (exit $rc)" >&2
    cat "$log" >&2
    exit "$rc"
  fi
  exe="$CARGO_TARGET_DIR/release/$bin"
  [ -x "$exe" ] || fail "$name: expected executable missing: $exe"
  out="$("$exe")" || fail "$name: executable failed"
  echo "$out"
  echo "$out" | grep -q "$expect" || fail "$name: missing '$expect'"
  pass=$((pass + 1))
}

run_rustc_case() {
  name="$1"
  src="$2"
  expect="$3"
  selected "$name" || return 0
  echo "--- $name ---"
  out_bin="$TMP_ROOT/$name"
  log="$TMP_ROOT/$name-rustc.log"
  if "$PREFIX/bin/rustc" -O "$src" -o "$out_bin" >"$log" 2>&1; then
    tail -n 2 "$log"
  else
    rc=$?
    echo "FAIL: $name compile failed (exit $rc)" >&2
    cat "$log" >&2
    exit "$rc"
  fi
  out="$("$out_bin")" || fail "$name: executable failed"
  echo "$out"
  echo "$out" | grep -q "$expect" || fail "$name: missing '$expect'"
  pass=$((pass + 1))
}

run_case proc-macro-derive "$HERE/pm-user" pm-user "pm ok"
run_case build-rs "$HERE/buildrs" buildrs "buildrs ok"
run_case ffi-cc "$HERE/ffivec" ffivec "ffi ok"
run_rustc_case threads-tls "$HERE/threads.rs" "threads ok"
run_rustc_case unwind "$HERE/unwind.rs" "unwind ok"
run_rustc_case hello "$HERE/hello.rs" "hello"

if [ "$STATIC" = "1" ]; then
  echo "--- static-pie ---"
  out_bin="$TMP_ROOT/static-pie"
  log="$TMP_ROOT/static-pie-rustc.log"
  if "$PREFIX/bin/rustc" -O -C target-feature=+crt-static "$HERE/static.rs" -o "$out_bin" >"$log" 2>&1; then
    tail -n 2 "$log"
  else
    rc=$?
    echo "FAIL: static-pie compile failed (exit $rc)" >&2
    cat "$log" >&2
    exit "$rc"
  fi
  readelf -l "$out_bin" >"$TMP_ROOT/static-pie-readelf.txt"
  if grep -q "INTERP" "$TMP_ROOT/static-pie-readelf.txt"; then
    fail "static-pie: produced an interpreter-dependent binary"
  fi
  readelf -d "$out_bin" >"$TMP_ROOT/static-pie-dynamic.txt" 2>&1 || true
  if grep -q "NEEDED" "$TMP_ROOT/static-pie-dynamic.txt"; then
    fail "static-pie: produced a binary with dynamic NEEDED entries"
  fi
  out="$("$out_bin")" || fail "static-pie: executable failed"
  echo "$out"
  echo "$out" | grep -q "static ok" || fail "static-pie: missing output"
  pass=$((pass + 1))
fi

echo "SMOKE_SUITE_OK cases=$pass"

#!/bin/sh
# S7 smoke runner: proc-macro / build.rs / FFI / threads-TLS / unwind.
# Usage: tests/smoke/run.sh --prefix <toolchain-prefix>
set -eu
PREFIX=""
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:-}"; shift 2;;
    *) echo "usage: run.sh --prefix <prefix>" >&2; exit 2;;
  esac
done
[ -n "$PREFIX" ] || { echo "missing --prefix" >&2; exit 2; }
[ -x "$PREFIX/bin/rustc" ] || { echo "no rustc in $PREFIX" >&2; exit 1; }
[ -x "$PREFIX/bin/cargo" ] || { echo "no cargo in $PREFIX" >&2; exit 1; }
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="$PREFIX/bin:$PATH"
export CARGO_NET_OFFLINE=true
# Declared runtime env (borrowed native unwind, dev only).
export LD_LIBRARY_PATH="$ROOT/../../.work/artifacts/seed-1.90/native/usr/lib:${LD_LIBRARY_PATH-}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH-}"
pass=0
run_case() {
  name="$1"; dir="$2"; bin="$3"; expect="$4"
  echo "--- $name ---"
  (cd "$dir" && cargo build --offline --release 2>&1 | tail -2)
  out=$("$dir/target/release/$bin")
  echo "$out"
  echo "$out" | grep -q "$expect" || { echo "FAIL: $name (missing '$expect')" >&2; exit 1; }
  pass=$((pass + 1))
}
run_case "proc-macro-derive" "$ROOT/pm-user" "pm-user" "pm ok"
run_case "build-rs" "$ROOT/buildrs" "buildrs" "buildrs ok"
run_case "ffi-cc" "$ROOT/ffivec" "ffivec" "ffi ok"
echo "--- threads-tls ---"
$PREFIX/bin/rustc -O "$ROOT/threads.rs" -o /tmp/opencode/s7-threads
/tmp/opencode/s7-threads | grep -q "threads ok" || exit 1
pass=$((pass + 1))
echo "--- unwind ---"
$PREFIX/bin/rustc -O "$ROOT/unwind.rs" -o /tmp/opencode/s7-unwind
/tmp/opencode/s7-unwind | grep -q "unwind ok" || exit 1
pass=$((pass + 1))
echo "SMOKE_SUITE_OK cases=$pass"

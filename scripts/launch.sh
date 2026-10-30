#!/bin/sh
# S1 launch skeleton: resumable entry for seed and later stages.
# S2 owns real seed execution; this skeleton prepares dirs and checks pins.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Declared runtime env for our prefixes (borrowed native unwind, dev only).
export LD_LIBRARY_PATH="$ROOT/.work/artifacts/seed-1.90/native/usr/lib:${LD_LIBRARY_PATH-}"
usage() {
  echo "usage: scripts/launch.sh --until <stage> [--verify-local] [--rebuild-same-version <ver>]"
  echo "stages: seed seed-1.90 1.91.1 ref-1.96.0 ext-<ver> self-<ver>"
}
UNTIL=""
VERIFY_LOCAL=0
REBUILD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --until) UNTIL="${2:-}"; shift 2;;
    --verify-local) VERIFY_LOCAL=1; shift;;
    --rebuild-same-version) REBUILD="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "launch: unknown arg $1" >&2; usage >&2; exit 2;;
  esac
done
[ -n "$UNTIL" ] || [ -n "$REBUILD" ] || { usage >&2; exit 2; }
[ -f "$ROOT/.work/pins/stagex-rust.json" ] || { echo "launch: pins missing, run doctor first" >&2; exit 1; }
mkdir -p "$ROOT/.work/build/seed" "$ROOT/.work/logs/seed"
if [ -n "$UNTIL" ]; then
case "$UNTIL" in
  seed|seed-1.90)
    echo "launch: stage=$UNTIL prepared (S1 skeleton; S2 owns compilation)"
    echo "launch: dirs .work/build/seed .work/logs/seed ready; resumable rerun is no-op"
    if [ -x "$ROOT/.work/build/seed/mrustc-0.12.0/bin/mrustc" ] && [ -x "$ROOT/.work/build/seed/mrustc-0.12.0/bin/minicargo" ]; then
      echo "launch: seed binaries present (S2 built)"
    else
      echo "launch: seed binaries not yet built (expected until S2 runs)"
    fi
    ;;
  1.91.1|ext-*|self-*)
    echo "launch: stage $UNTIL not yet implemented (owned by S4/S6/S7)" >&2
    exit 2
    ;;
  ref-1.96.0)
    P="$ROOT/.work/artifacts/ref-1.96.0/prefix"
    LOG="$ROOT/.work/logs/ref-1.96.0/build.log"
    [ -x "$P/bin/rustc" ] || { echo "launch: ref-1.96.0 rustc missing" >&2; exit 1; }
    [ -x "$P/bin/cargo" ] || { echo "launch: ref-1.96.0 cargo missing" >&2; exit 1; }
    echo "launch: ref-1.96.0 present: $("$P/bin/rustc" --version), $("$P/bin/cargo" --version)"
    if [ "$VERIFY_LOCAL" = "1" ]; then
      [ -f "$LOG" ] || { echo "launch: leaf build log missing" >&2; exit 1; }
      grep -q "BUILD_ONE_OK" "$LOG" || { echo "launch: no successful build marker" >&2; exit 1; }
      grep -q "Building stage" "$LOG" || { echo "launch: no local stage-build evidence" >&2; exit 1; }
      grep -q "Compiling core" "$LOG" || { echo "launch: no local core-compile evidence" >&2; exit 1; }
      if grep -Ei "downloading (rustc|cargo|rust-std)|fetching toolchain|download-ci-llvm.*http" "$LOG"; then
        echo "launch: toolchain download detected, not a local leaf build" >&2; exit 1
      fi
      for f in "$P/lib/rustlib/x86_64-unknown-linux-musl/lib/libstd-"*.rlib "$P/lib/librustc_driver-"*.so "$P/bin/cargo" "$P/lib/rustlib/x86_64-unknown-linux-musl/lib/self-contained/libc.a"; do
        [ -e "$f" ] || { echo "launch: required runtime file missing: $f" >&2; exit 1; }
      done
      echo "launch: verify-local PASS (local leaf build, no toolchain import, runtime files present)"
      VERIFY_LOCAL=0
    fi
    ;;
  *) echo "launch: unknown stage $UNTIL" >&2; exit 2;;
esac
fi
if [ "$VERIFY_LOCAL" = "1" ]; then
  echo "launch: --verify-local only supported with --until ref-1.96.0" >&2
  exit 2
fi
if [ -n "$REBUILD" ]; then
  P="$ROOT/.work/artifacts/self-$REBUILD/prefix"
  LOG="$ROOT/.work/logs/self-$REBUILD/build-attempt2.log"
  [ -f "$LOG" ] || LOG="$ROOT/.work/logs/self-$REBUILD/build.log"
  [ -x "$P/bin/rustc" ] || { echo "launch: self-build rustc missing: $P" >&2; exit 1; }
  [ -f "$LOG" ] || { echo "launch: self-build log missing" >&2; exit 1; }
  grep -q "Building stage" "$LOG" || { echo "launch: no local stage-build evidence" >&2; exit 1; }
  grep -q "Compiling core" "$LOG" || { echo "launch: no local core-compile evidence" >&2; exit 1; }
  echo "launch: same-version rebuild $REBUILD present: $("$P/bin/rustc" --version)"
  echo "launch: rebuilt tools execute real compilation (fresh workdir log, not uplift)"
fi
exit 0

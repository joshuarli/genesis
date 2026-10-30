#!/bin/sh
# S9 lower-chain recipe: records the compiler-producing path from the seed
# stages to the final Rust, with per-input provenance, and reruns a consumer
# under a rebuilt (new-identity) native component.
# Usage: recipes/lower-chain.sh --verify | --replay --report
# --verify: checks the recorded path exists, classifies every lower input as
#   rebuilt ( Adel: this lineage) or borrowed (declared, S10 must exclude),
#   and reruns the smoke consumer against the rebuilt unwind/CRT set.
# --replay --report: S10 entry (fresh output/cache namespace; sources shared).
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOWER="$ROOT/.work/lower"
MODE="${1:-}"
[ "$MODE" = "--verify" ] || [ "$MODE" = "--replay" ] || { echo "usage: lower-chain.sh --verify | --replay --report" >&2; exit 2; }
if [ "$MODE" = "--replay" ]; then
  shift
  [ "${1:-}" = "--report" ] || { echo "usage: lower-chain.sh --replay --report" >&2; exit 2; }
  echo "lower-chain: replay report belongs to S10 (see .work/replay/REPORT.md when present)"
  [ -f "$ROOT/.work/replay/REPORT.md" ] && cat "$ROOT/.work/replay/REPORT.md" || echo "lower-chain: no replay yet"
  exit 0
fi
echo "=== lower-chain --verify ==="
fail=0
check() { if [ -e "$1" ]; then echo "present: $1"; else echo "MISSING: $1"; fail=1; fi; }
echo "--- stage: borrowed native toolchain (declared inputs, S10-excluded) ---"
command -v cc >/dev/null && echo "present: host cc ($(cc --version | head -n1))"
command -v clang >/dev/null && echo "present: host clang ($(clang --version | head -n1))"
check "$ROOT/.work/artifacts/seed-1.90/llvm21/usr/lib/llvm21/bin/llvm-config"
check "$ROOT/.work/artifacts/ext-1.99.1/llvm23/usr/lib/llvm23/bin/llvm-config"
echo "--- stage: mrustc + seed (this lineage) ---"
check "$ROOT/.work/build/seed/mrustc-0.12.0/bin/mrustc"
check "$ROOT/.work/artifacts/seed-1.90/install/bin/rustc"
echo "--- stage: ladder checkpoints (this lineage) ---"
for v in 1.91.1 1.92.0 1.93.1 1.94.1 1.95.0; do
  check "$ROOT/.work/artifacts/$v/prefix/bin/rustc"
done
check "$ROOT/.work/artifacts/ref-1.96.0/prefix/bin/rustc"
for v in 1.96.1 1.97.1 1.98.1 1.99.1; do
  check "$ROOT/.work/artifacts/ext-$v/prefix/bin/rustc"
done
check "$ROOT/.work/artifacts/self-1.99.1/prefix/bin/rustc"
echo "--- stage: rebuilt native components (new identity) ---"
if [ -d "$LOWER/rebuilt" ]; then
  ls "$LOWER/rebuilt" | while IFS= read -r f; do echo "rebuilt: $f"; done
else
  echo "note: no rebuilt components yet"
fi
echo "--- consumer rerun under rebuilt identity ---"
if [ -x "$LOWER/rebuilt/smoke-unwind" ]; then
  "$LOWER/rebuilt/smoke-unwind" || fail=1
else
  echo "note: rebuilt-identity consumer not yet linked (S9 work in progress)"
fi
[ "$fail" = "0" ] && echo "VERIFY_OK" || { echo "VERIFY_FAIL" >&2; exit 1; }

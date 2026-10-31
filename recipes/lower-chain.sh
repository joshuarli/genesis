#!/bin/sh
# Lower-chain and Rust-PoC operations with honest failure states.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

usage() {
  cat <<'EOF'
usage: recipes/lower-chain.sh <command> [options]

commands:
  inventory            list chain artifacts and rebuilt lower components
  verify-rust-poc      run the functional tests against the final prefix
  replay-rust-chain    execute a fresh build (recipes/replay.sh)
  verify-lower-closure fail unless compiler-producing consumers were rebuilt
  show-report          print the recorded lower/replay reports, if any
EOF
}

cmd="${1:-}"
[ -n "$cmd" ] || { usage >&2; exit 2; }
shift || true

inventory() {
  echo "=== chain inventory ==="
  for stage in $(all_stages); do
    state="$(stage_state "$stage")"
    printf '%-14s %-14s %s\n' "$stage" "$state" "$(stage_prefix "$stage" 2>/dev/null || echo '?')"
  done
  echo "=== rebuilt lower components ==="
  if [ -d "$WORK/lower/rebuilt" ]; then
    find "$WORK/lower/rebuilt" -maxdepth 3 -type f | sort | sed -n '1,80p'
  else
    echo "none"
  fi
  echo "inventory: complete (this command does not verify ancestry)"
}

verify_rust_poc() {
  FINAL_STAGE="ext-1.99.1"
  PREFIX="$(stage_prefix "$FINAL_STAGE")"
  verify_stage "$FINAL_STAGE" >/dev/null 2>&1 || die "final toolchain is not built: $FINAL_STAGE"
  echo "=== Rust PoC: smoke ==="
  "$ROOT/tests/smoke/run.sh" --prefix "$PREFIX" --static
  echo "=== Rust PoC: external CLI ==="
  "$ROOT/tests/external/run.sh" --prefix "$PREFIX"
  echo "RUST_POC_OK"
}

verify_lower_closure() {
  echo "=== lower closure ==="
  fail=0
  [ -d "$WORK/lower/rebuilt" ] || { echo "MISSING: $WORK/lower/rebuilt"; fail=1; }
  [ -f "$WORK/lower/rebuilt/lib/libunwind.a" ] || { echo "MISSING: rebuilt libunwind.a"; fail=1; }
  [ -x "$WORK/lower/rebuilt/smoke-unwind" ] || { echo "MISSING: rebuilt-identity smoke consumer"; fail=1; }
  if [ ! -f "$WORK/lower/consumers-rebuilt" ]; then
    echo "INCOMPLETE: no compiler-producing consumer (mrustc, seed rustc, or ladder rustc)"
    echo "INCOMPLETE: was rebuilt under the rebuilt lower lineage"
    echo "INCOMPLETE: relinking a smoke program does not change the Rust compiler ancestry"
    fail=1
  fi
  if [ "$fail" = "0" ]; then
    echo "LOWER_CLOSURE_OK"
  else
    echo "LOWER_CLOSURE_INCOMPLETE" >&2
    exit 1
  fi
}

case "$cmd" in
  inventory) inventory ;;
  verify-rust-poc) verify_rust_poc ;;
  replay-rust-chain) exec "$ROOT/recipes/replay.sh" "$@" ;;
  verify-lower-closure) verify_lower_closure ;;
  show-report)
    for f in "$WORK/lower/REPORT.md" "$WORK/replay/REPORT.md"; do
      if [ -f "$f" ]; then echo "=== $f ==="; cat "$f"; else echo "=== $f: absent ==="; fi
    done
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac

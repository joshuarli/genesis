#!/bin/sh
# Lower-chain and Rust-PoC operations with honest failure states.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"
LOWER_WORK="${GENESIS_LOWER_WORK:-$WORK/lower/work}"

usage() {
  cat <<'EOF'
usage: recipes/lower-chain.sh <command> [options]

commands:
  closure [target]     measure the StageX dependency closure (default core-rust)
  build [--stage S]    build the StageX closure and extend it to 1.99.1
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

stagex_closure() {
  target="${1:-core-rust}"
  ensure_stagex_source
  python3 "$ROOT/recipes/stagex-closure.py" \
    --stagex-src "$(stagex_source_dir)" \
    --target "$target" \
    --commit "$(manifest_field stagex.commit)"
}

inventory() {
  echo "=== chain inventory ==="
  for stage in $(all_stages); do
    state="$(stage_state "$stage")"
    printf '%-14s %-14s %s\n' "$stage" "$state" "$(stage_prefix "$stage" 2>/dev/null || echo '?')"
  done
  echo "=== lower lineage ==="
  for stage in $(lower_stages); do
    prefix="$LOWER_WORK/artifacts/$(release_field "$stage" artifact)/prefix"
    if [ -x "$prefix/bin/rustc" ]; then
      printf '%-14s %-14s %s\n' "$stage" "built" "$prefix"
    else
      printf '%-14s %-14s %s\n' "$stage" "missing" "$prefix"
    fi
  done
  if [ -f "$LOWER_WORK/consumers-rebuilt" ]; then
    echo "=== lower receipt ==="
    cat "$LOWER_WORK/consumers-rebuilt"
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
  receipt="$LOWER_WORK/consumers-rebuilt"
  if [ ! -f "$receipt" ]; then
    echo "MISSING: $receipt"
    echo "INCOMPLETE: no compiler-producing consumer was rebuilt under the StageX lineage"
    fail=1
  else
    grep -q '^stagex_commit=' "$receipt" || { echo "INVALID: receipt lacks stagex_commit"; fail=1; }
    grep -q '^core_rust_digest=sha256:' "$receipt" || { echo "INVALID: receipt lacks core-rust digest"; fail=1; }
    grep -q '^smoke=SMOKE_SUITE_OK' "$receipt" || { echo "INVALID: receipt lacks passing smoke result"; fail=1; }
    grep -q '^external=EXTERNAL_OK' "$receipt" || { echo "INVALID: receipt lacks passing external result"; fail=1; }
  fi
  for stage in stagex-1.96.0 stagex-1.97.1 stagex-1.98.1 stagex-1.99.1; do
    prefix="$LOWER_WORK/artifacts/$(release_field "$stage" artifact)/prefix"
    [ -x "$prefix/bin/rustc" ] || { echo "MISSING: $stage rustc ($prefix)"; fail=1; }
    [ -x "$prefix/bin/cargo" ] || { echo "MISSING: $stage cargo ($prefix)"; fail=1; }
  done
  if [ "$fail" = "0" ]; then
    echo "=== rerun smoke and external tests against the lower prefix ==="
    GENESIS_WORK="$LOWER_WORK" "$ROOT/tests/smoke/run.sh" \
      --prefix "$LOWER_WORK/artifacts/stagex-1.99.1/prefix" --static || fail=1
    GENESIS_WORK="$LOWER_WORK" "$ROOT/tests/external/run.sh" \
      --prefix "$LOWER_WORK/artifacts/stagex-1.99.1/prefix" \
      --work-dir "$LOWER_WORK/external" || fail=1
  fi
  if [ "$fail" = "0" ]; then
    echo "LOWER_CLOSURE_OK"
  else
    echo "LOWER_CLOSURE_INCOMPLETE" >&2
    exit 1
  fi
}

case "$cmd" in
  closure) stagex_closure "${1:-core-rust}" ;;
  build) exec "$ROOT/recipes/lower-build.sh" "$@" ;;
  inventory) inventory ;;
  verify-rust-poc) verify_rust_poc ;;
  replay-rust-chain) exec "$ROOT/recipes/replay.sh" "$@" ;;
  verify-lower-closure) verify_lower_closure ;;
  show-report)
    for f in "$LOWER_WORK/REPORT.md" "$WORK/lower/REPORT.md" "$WORK/replay/REPORT.md"; do
      if [ -f "$f" ]; then echo "=== $f ==="; cat "$f"; else echo "=== $f: absent ==="; fi
    done
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac

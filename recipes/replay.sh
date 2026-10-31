#!/bin/sh
# Build the recorded Rust 1.99.1 chain from a fresh work directory.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

WORK_ARG=""
UNTIL=""
NO_SELF=0
NO_CCACHE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --work-dir) WORK_ARG="${2:-}"; shift 2 ;;
    --until) UNTIL="${2:-}"; shift 2 ;;
    --no-self) NO_SELF=1; shift ;;
    --no-ccache) NO_CCACHE=1; shift ;;
    -h|--help)
      cat <<'EOF'
usage: recipes/replay.sh [--work-dir DIR] [--until STAGE] [--no-self] [--no-ccache]

Builds mrustc, the 1.90 seed, the 1.96.0 reference endpoint, the 1.96.1
extension branch, 1.99.1, and a same-version 1.99.1 rebuild in DIR.
Sources and native APKs are downloaded from sources.toml and verified by hash.
EOF
      exit 0
      ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -n "$WORK_ARG" ]; then
  case "$WORK_ARG" in
    /*) WORK="$WORK_ARG" ;;
    *) WORK="$(cd "$(dirname "$WORK_ARG")" 2>/dev/null && pwd)/$(basename "$WORK_ARG")" ;;
  esac
else
  WORK="${GENESIS_WORK:-$ROOT/.work/replay-$(date -u +%Y%m%dT%H%M%SZ)}"
fi
mkdir -p "$WORK"
export GENESIS_WORK="$WORK"
export GENESIS_REPLAY=1
export GENESIS_CCACHE_NAMESPACE=replay
export GENESIS_JOBS="${GENESIS_JOBS:-8}"
export GENESIS_PARLEVEL="${GENESIS_PARLEVEL:-8}"

. "$HERE/common.sh"

if [ -n "${MINICARGO_DEFER_CODEGEN+x}" ]; then
  die "MINICARGO_DEFER_CODEGEN is set; mrustc generates C here"
fi
if [ "$NO_CCACHE" = "1" ]; then
  export CCACHE_DISABLE=1
else
  unset CCACHE_DISABLE
  export CCACHE_DIR="$WORK/cache/ccache-replay"
  setup_ccache replay || true
fi

MOLD_DIR="$(dirname "$(command -v mold)")"
export PATH="$WORK/tools:$MOLD_DIR:/usr/local/bin:/usr/bin:/bin"
ln -sfn "$(command -v mold)" "$WORK/tools/mold" 2>/dev/null || true
if command -v cargo >/dev/null 2>&1; then
  die "ambient cargo is visible on the replay PATH: $(command -v cargo)"
fi
if command -v rustc >/dev/null 2>&1; then
  die "ambient rustc is visible on the replay PATH: $(command -v rustc)"
fi

clear_rust_environment
export CARGO_HOME="$WORK/cargo-home"
export CARGO_NET_OFFLINE=true
export CC=cc CXX=c++ HOST_CC=cc HOST_CXX=c++
export RUSTC_WRAPPER=
export RUSTC_WORKSPACE_WRAPPER=
mkdir -p "$WORK/downloads" "$WORK/logs" "$WORK/state" "$WORK/tools" "$CARGO_HOME"

TARGET_STAGE="${UNTIL:-self-1.99.1}"
if [ "$NO_SELF" = "1" ] && [ -z "$UNTIL" ]; then
  TARGET_STAGE="ext-1.99.1"
fi
case "$TARGET_STAGE" in
  1.96.0|ref-1.96.0) TARGET_STAGE="ref-1.96.0" ;;
  1.99.1|ext-1.99.1) TARGET_STAGE="ext-1.99.1" ;;
  1.96.1) TARGET_STAGE="ext-1.96.1" ;;
  1.97.1) TARGET_STAGE="ext-1.97.1" ;;
  1.98.1) TARGET_STAGE="ext-1.98.1" ;;
esac

START="$(date +%s)"
START_UTC="$(date -u +%FT%TZ)"
echo "=== replay $START_UTC ==="
echo "source: $ROOT"
echo "work: $WORK"
echo "target stage: $TARGET_STAGE"
git -C "$ROOT" rev-parse HEAD 2>/dev/null || true
if [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
  echo "warning: source tree has local changes"
fi
uname -a
nproc
free -g | head -n2

echo "=== reference endpoint 1.96.0 ==="
"$ROOT/scripts/launch.sh" --until ref-1.96.0

echo "=== extension branch and destination ==="
"$ROOT/scripts/launch.sh" --until "$TARGET_STAGE"

FINAL_STAGE="ext-1.99.1"
FINAL_PREFIX="$(stage_prefix "$FINAL_STAGE")"
verify_stage "$FINAL_STAGE" >/dev/null || die "final toolchain verification failed"

echo "=== functional tests ==="
"$ROOT/tests/smoke/run.sh" --prefix "$FINAL_PREFIX" --work-dir "$WORK/tests/smoke-final"
"$ROOT/tests/external/run.sh" --prefix "$FINAL_PREFIX" --work-dir "$WORK/tests/external-final"

echo "=== relocated toolchain test ==="
REL="$WORK/relocated"
rm -rf "$REL"
mkdir -p "$REL"
cp -a "$FINAL_PREFIX" "$REL/prefix"
hidden=""
hide_dir() {
  if [ -d "$1" ]; then
    mv "$1" "$1.hidden-replay"
    hidden="$1:$hidden"
  fi
}
restore_hidden() {
  for d in $(echo "$hidden" | tr ':' ' '); do
    [ -e "$d.hidden-replay" ] && mv "$d.hidden-replay" "$d"
  done
  hidden=""
}
trap 'restore_hidden' EXIT INT TERM
hide_dir "$WORK/build"
hide_dir "$WORK/artifacts"
hide_dir "$WORK/downloads"
"$ROOT/tests/smoke/run.sh" --prefix "$REL/prefix" --work-dir "$WORK/tests/relocated"
restore_hidden
trap - EXIT INT TERM

echo "=== ccache ==="
CCACHE_STATS=""
if [ "$NO_CCACHE" = "0" ] && command -v ccache >/dev/null 2>&1; then
  CCACHE_STATS="$(ccache -s 2>&1 || true)"
  printf '%s\n' "$CCACHE_STATS"
fi

END="$(date +%s)"
ELAPSED=$((END - START))
{
  echo "# Fresh replay report"
  echo
  echo "- source commit: $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "- work dir: $WORK"
  echo "- target stage: $TARGET_STAGE"
  echo "- started: $START_UTC"
  echo "- elapsed seconds: $ELAPSED"
  echo "- host: $(uname -sm), nproc=$(nproc)"
  echo "- ccache: $([ "$NO_CCACHE" = "1" ] && echo disabled || echo "$CCACHE_DIR")"
  echo
  echo "## Toolchain versions"
  for stage in $(all_stages); do
    prefix="$(stage_prefix "$stage")"
    if [ -x "$prefix/bin/rustc" ]; then
      printf -- '- %s: %s / %s\n' "$stage" "$("$prefix/bin/rustc" --version 2>/dev/null | head -n1)" "$("$prefix/bin/cargo" --version 2>/dev/null | head -n1)"
    else
      printf -- '- %s: not built\n' "$stage"
    fi
  done
  echo
  echo "## Provenance"
  echo "- built in this work dir: mrustc/minicargo, the 1.90 seed, every ladder rung, and the same-version rebuild"
  echo "- shared sources: downloaded from sources.toml and verified by SHA-256"
  echo "- borrowed runtime/tools: host cc/c++/clang/musl-dev, mold, python3, make, tar, curl, ccache"
  echo "- no ambient rustc/cargo was visible on PATH"
  echo
  echo "## Results"
  echo "- smoke suite: pass (final and relocated prefixes)"
  echo "- external rustfilt 0.2.1: pass"
  echo "- same-version rebuild: $([ "$TARGET_STAGE" = "self-1.99.1" ] && echo pass || echo not requested)"
  echo "- relocation: pass (build/artifacts/downloads hidden)"
  echo
  echo "## ccache"
  if [ -n "$CCACHE_STATS" ]; then
    printf '%s\n' "$CCACHE_STATS" | sed 's/^/    /'
  else
    echo "- disabled or unavailable"
  fi
  echo
  echo "## Runtime contract"
  echo "- RUST_MIN_STACK=16777216 is used for LLVM-23 compiler builds (1.99.1 and self-build)."
  echo "- Functional smoke and external tests run without it; compiler-sized LTO builds should keep it."
} > "$WORK/REPLAY.md"
cat "$WORK/REPLAY.md"
echo "REPLAY_OK $TARGET_STAGE"

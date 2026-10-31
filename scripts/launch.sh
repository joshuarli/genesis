#!/bin/sh
# Build, verify, or inspect the pinned Rust bootstrap chain.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../recipes/common.sh"

usage() {
  cat <<'EOF'
usage: scripts/launch.sh [--until STAGE] [--verify [STAGE]] [--status] [--list]
                         [--rebuild-same-version VERSION] [--force]

STAGE is seed, seed-1.90, 1.91.1, 1.92.0, 1.93.1, 1.94.1, 1.95.0,
ref-1.96.0, ext-1.96.1, ext-1.97.1, ext-1.98.1, ext-1.99.1, self-1.99.1.
--until builds the named stage and its missing prerequisites.
--verify inspects existing artifacts without building.
--status reports not-attempted, incomplete, failed, or passed per stage.
--rebuild-same-version builds self-<version> from its same-version predecessor.
EOF
}

canonical_stage() {
  case "$1" in
    1.91.1|1.92.0|1.93.1|1.94.1|1.95.0) echo "$1" ;;
    1.96.0|ref-1.96.0) echo "ref-1.96.0" ;;
    1.96.1) echo "ext-1.96.1" ;;
    1.97.1) echo "ext-1.97.1" ;;
    1.98.1) echo "ext-1.98.1" ;;
    1.99.1|ext-1.99.1) echo "ext-1.99.1" ;;
    self-1.99.1) echo "self-1.99.1" ;;
    seed|seed-1.90) echo "$1" ;;
    *) return 1 ;;
  esac
}

stage_recipe() {
  case "$1" in
    seed) echo "$ROOT/recipes/seed-tools.sh" ;;
    seed-1.90) echo "$ROOT/recipes/seed-rust.sh" ;;
    *) echo "$ROOT/recipes/build-rust.sh" ;;
  esac
}

build_stage() {
  stage="$1"
  if verify_stage "$stage" >/dev/null 2>&1; then
    note "stage $stage already complete (no build performed)"
    state_write "$stage" passed "verified existing artifacts"
    return 0
  fi
  if [ "$FORCE" = "1" ] && [ "$stage" = "$FORCE_STAGE" ]; then
    prefix="$(stage_prefix "$stage")"
    case "$prefix" in
      "$WORK"/*) rm -rf "$prefix" ;;
      *) die "refusing to remove prefix outside work dir: $prefix" ;;
    esac
    if [ "$stage" != "seed" ] && [ "$stage" != "seed-1.90" ]; then
      artifact="$(release_field "$stage" artifact)"
      build_dir="$BUILDS/$artifact"
      case "$build_dir" in
        "$WORK"/*) rm -rf "$build_dir" ;;
        *) die "refusing to remove build dir outside work dir: $build_dir" ;;
      esac
    fi
    note "forced rebuild: removed $prefix"
  fi
  recipe="$(stage_recipe "$stage")"
  if [ "$stage" = "seed" ] || [ "$stage" = "seed-1.90" ]; then
    run_stage "$stage" "$recipe"
  else
    run_stage "$stage" "$recipe" --stage "$stage"
  fi
}

build_until() {
  plan=""
  current="$1"
  while [ -n "$current" ]; do
    plan="$current $plan"
    current="$(stage_deps "$current")"
  done
  for build_target in $plan; do
    build_stage "$build_target"
  done
}

print_status() {
  printf '%-14s %-14s %-8s %s\n' "STAGE" "STATE" "VERSION" "ARTIFACT"
  for stage in $(all_stages); do
    state="$(stage_state "$stage")"
    version="$(stage_version "$stage" 2>/dev/null || echo '?')"
    artifact="$(stage_prefix "$stage" 2>/dev/null || echo '?')"
    printf '%-14s %-14s %-8s %s\n' "$stage" "$state" "$version" "$artifact"
    detail="$(state_detail "$stage")"
    [ -n "$detail" ] && printf '  last: %s\n' "$detail"
  done
  return 0
}

UNTIL=""
VERIFY_STAGE=""
VERIFY_ONLY=0
STATUS=0
LIST=0
REBUILD=""
FORCE=0
FORCE_STAGE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --until) UNTIL="${2:-}"; shift 2 ;;
    --verify)
      VERIFY_ONLY=1
      if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then VERIFY_STAGE="$2"; shift 2; else shift; fi
      ;;
    --status) STATUS=1; shift ;;
    --list) LIST=1; shift ;;
    --rebuild-same-version) REBUILD="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

if [ "$LIST" = "1" ]; then
  for stage in $(all_stages); do
    printf '%-14s deps: %s\n' "$stage" "$(stage_deps "$stage")"
  done
  exit 0
fi

if [ "$STATUS" = "1" ]; then
  print_status
  exit 0
fi

if [ -n "$REBUILD" ]; then
  case "$REBUILD" in
    1.99.1) REBUILD_STAGE="self-1.99.1" ;;
    *) die "same-version rebuild is implemented for 1.99.1 only" ;;
  esac
  UNTIL="$REBUILD_STAGE"
  FORCE_STAGE="$REBUILD_STAGE"
fi

if [ "$VERIFY_ONLY" = "1" ]; then
  if [ -n "$VERIFY_STAGE" ]; then
    stage="$(canonical_stage "$VERIFY_STAGE")" || die "unknown or unsupported stage: $VERIFY_STAGE"
    if ! verify_stage "$stage"; then
      die "verify failed for $stage"
    fi
    note "verify $stage: artifact check passed"
    note "this checks the installed artifacts; it does not prove build ancestry"
    exit 0
  fi
  fail=0
  for stage in $(all_stages); do
    if verify_stage "$stage" >/dev/null 2>&1; then
      note "verify $stage: pass"
    else
      note "verify $stage: missing-or-invalid"
      fail=1
    fi
  done
  [ "$fail" = "0" ] || exit 1
  exit 0
fi

[ -n "$UNTIL" ] || { usage >&2; exit 2; }
stage="$(canonical_stage "$UNTIL")" || die "unknown or unsupported stage: $UNTIL"
note "work dir: $WORK"
note "target: $UNTIL (stage $stage)"
build_until "$stage"
note "build $UNTIL: pass"

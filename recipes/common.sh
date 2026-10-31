#!/bin/sh
# Shared paths, source verification, stage state, and toolchain environment.
set -eu

ROOT="${GENESIS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WORK="${GENESIS_WORK:-$ROOT/.work}"
TARGET="x86_64-unknown-linux-musl"
SOURCES="$ROOT/sources.toml"
SOURCES_PY="$ROOT/recipes/sources.py"
DOWNLOADS="$WORK/downloads"
ARTIFACTS="$WORK/artifacts"
BUILDS="$WORK/build"
LOGS="$WORK/logs"
STATE="$WORK/state"
CACHE="$WORK/cache"
TOOLS="$WORK/tools"
CARGO_HOME_ISOLATED="$WORK/cargo-home"

JOBS="${GENESIS_JOBS:-8}"
CXX_JOBS="${GENESIS_CXX_JOBS:-12}"
PARLEVEL="${GENESIS_PARLEVEL:-8}"

mkdir -p "$DOWNLOADS" "$ARTIFACTS" "$BUILDS" "$LOGS" "$STATE" "$CACHE" "$TOOLS" "$CARGO_HOME_ISOLATED"

die() {
  echo "genesis: $*" >&2
  exit 1
}

note() {
  echo "genesis: $*"
}

source_field() {
  python3 "$SOURCES_PY" source "$1" "$2"
}

manifest_field() {
  python3 "$SOURCES_PY" field "$1"
}

release_field() {
  python3 "$SOURCES_PY" release "$1" "$2"
}

release_stages() {
  python3 "$SOURCES_PY" releases
}

all_stages() {
  python3 "$SOURCES_PY" list
}

stage_exists() {
  python3 "$SOURCES_PY" release "$1" stage >/dev/null 2>&1 || [ "$1" = "seed" ] || [ "$1" = "seed-1.90" ]
}

stage_prefix() {
  case "$1" in
    seed) echo "$BUILDS/seed/mrustc-0.12.0" ;;
    seed-1.90) echo "$ARTIFACTS/seed-1.90/install" ;;
    *) echo "$ARTIFACTS/$(release_field "$1" artifact)/prefix" ;;
  esac
}

stage_deps() {
  case "$1" in
    seed) ;;
    seed-1.90) echo "seed" ;;
    *) release_field "$1" predecessor ;;
  esac
}

stage_source() {
  [ "$1" != "seed" ] && [ "$1" != "seed-1.90" ] || return 0
  release_field "$1" source
}

stage_version() {
  case "$1" in
    seed) echo "mrustc-0.12.0" ;;
    seed-1.90) echo "1.90.0" ;;
    *) release_field "$1" stage | sed -e 's/^ext-//' -e 's/^ref-//' -e 's/^self-//' ;;
  esac
}

stage_artifact() {
  case "$1" in
    seed) echo "build/seed" ;;
    seed-1.90) echo "artifacts/seed-1.90" ;;
    *) echo "artifacts/$(release_field "$1" artifact)" ;;
  esac
}

state_file() {
  echo "$STATE/$1"
}

state_write() {
  stage="$1"
  state="$2"
  detail="${3:-}"
  {
    echo "stage=$stage"
    echo "state=$state"
    echo "date=$(date -u +%FT%TZ)"
    [ -n "$detail" ] && echo "detail=$detail"
  } > "$(state_file "$stage").tmp"
  mv "$(state_file "$stage").tmp" "$(state_file "$stage")"
}

state_get() {
  f="$(state_file "$1")"
  if [ -f "$f" ]; then
    sed -n 's/^state=//p' "$f" | head -n1
  else
    echo "not-attempted"
  fi
}

state_detail() {
  f="$(state_file "$1")"
  if [ -f "$f" ]; then
    sed -n 's/^detail=//p' "$f" | head -n1
  fi
}

sha256_of() {
  sha256sum "$1" | awk '{print $1}'
}

verify_sha256() {
  _verify_file="$1"
  _verify_expected="$2"
  [ -f "$_verify_file" ] || return 1
  _verify_actual="$(sha256_of "$_verify_file")"
  [ "$_verify_actual" = "$_verify_expected" ] || die "sha256 mismatch for $_verify_file: $_verify_actual != $_verify_expected"
}

download_source() {
  _ds_key="$1"
  _ds_dest="$2"
  _ds_url="$(source_field "$_ds_key" url)"
  _ds_expected="$(source_field "$_ds_key" sha256)"
  if [ -f "$_ds_dest" ]; then
    verify_sha256 "$_ds_dest" "$_ds_expected"
    return 0
  fi
  mkdir -p "$(dirname "$_ds_dest")"
  _ds_tmp="$_ds_dest.part"
  rm -f "$_ds_tmp"
  note "download $_ds_url"
  curl -fL --retry 4 --retry-delay 2 --connect-timeout 20 -o "$_ds_tmp" "$_ds_url" || die "download failed: $_ds_url"
  verify_sha256 "$_ds_tmp" "$_ds_expected"
  mv "$_ds_tmp" "$_ds_dest"
}

download_native_group() {
  _dng_group="$1"
  _dng_dest="$2"
  _dng_base="$(python3 "$SOURCES_PY" native "$_dng_group" base_url)"
  mkdir -p "$_dng_dest"
  python3 "$SOURCES_PY" native "$_dng_group" packages | while IFS="$(printf '\t')" read -r _dng_name _dng_version _dng_sha; do
    _dng_file="$_dng_dest/$_dng_name-$_dng_version.apk"
    if [ -f "$_dng_file" ]; then
      verify_sha256 "$_dng_file" "$_dng_sha"
    else
      _dng_url="$_dng_base/$_dng_name-$_dng_version.apk"
      note "download $_dng_url"
      _dng_tmp="$_dng_file.part"
      rm -f "$_dng_tmp"
      curl -fL --retry 4 --retry-delay 2 --connect-timeout 20 -o "$_dng_tmp" "$_dng_url" || die "download failed: $_dng_url"
      verify_sha256 "$_dng_tmp" "$_dng_sha"
      mv "$_dng_tmp" "$_dng_file"
    fi
  done
}

extract_native_group() {
  _eng_group="$1"
  _eng_dest="$2"
  _eng_dl="$DOWNLOADS/native/$_eng_group"
  download_native_group "$_eng_group" "$_eng_dl"
  mkdir -p "$_eng_dest"
  python3 "$SOURCES_PY" native "$_eng_group" packages | while IFS="$(printf '\t')" read -r _eng_name _eng_version _eng_sha; do
    _eng_file="$_eng_dl/$_eng_name-$_eng_version.apk"
    note "extract $_eng_name-$_eng_version"
    tar -xzf "$_eng_file" -C "$_eng_dest"
  done
}

extract_archive() {
  _ea_archive="$1"
  _ea_dest="$2"
  _ea_marker="$3"
  if [ -e "$_ea_marker" ]; then
    return 0
  fi
  mkdir -p "$_ea_dest"
  note "extract $(basename "$_ea_archive")"
  tar -xzf "$_ea_archive" -C "$_ea_dest"
}

apply_patch() {
  patch_file="$1"
  strip="${2:-1}"
  [ -f "$patch_file" ] || die "patch missing: $patch_file"
  if patch -p"$strip" -N -R --dry-run -s -i "$patch_file" >/dev/null 2>&1; then
    note "already applied: $(basename "$patch_file")"
    return 0
  fi
  if patch -p"$strip" -N --dry-run -s -i "$patch_file" >/dev/null 2>&1; then
    patch -p"$strip" -N -s -i "$patch_file"
    note "applied: $(basename "$patch_file")"
    return 0
  fi
  die "patch does not apply cleanly: $patch_file"
}

clear_rust_environment() {
  unset RUSTC_WRAPPER RUSTC_WORKSPACE_WRAPPER RUSTFLAGS RUSTDOCFLAGS LD_PRELOAD
  export RUSTC_WRAPPER=
  export RUSTC_WORKSPACE_WRAPPER=
  export CARGO_HOME="$CARGO_HOME_ISOLATED"
  export CARGO_NET_OFFLINE=true
}

setup_ccache() {
  namespace="${1:-dev}"
  if ! command -v ccache >/dev/null 2>&1; then
    note "ccache not found; continuing without C/C++ cache"
    return 1
  fi
  if [ -z "${CCACHE_DIR:-}" ]; then
    export CCACHE_DIR="$CACHE/ccache-$namespace"
  fi
  export CCACHE_CONFIGPATH="$CCACHE_DIR/ccache.conf"
  mkdir -p "$CCACHE_DIR"
  if [ ! -f "$CCACHE_CONFIGPATH" ]; then
    cat > "$CCACHE_CONFIGPATH" <<'EOF'
max_size = 30.0G
compiler_check = content
compression = true
hard_link = false
sloppiness =
hash_dir = false
EOF
  fi
  return 0
}

ccache_cxx() {
  if command -v ccache >/dev/null 2>&1; then
    echo "ccache c++"
  else
    echo "c++"
  fi
}

llvm21_root() {
  echo "$ARTIFACTS/seed-1.90/llvm21/usr/lib/llvm21"
}

llvm23_root() {
  echo "$ARTIFACTS/ext-1.99.1/llvm23/usr/lib/llvm23"
}

native_unwind_root() {
  echo "$ARTIFACTS/seed-1.90/native"
}

use_native_unwind_runtime() {
  native="$(native_unwind_root)"
  LIBRARY_PATH="$native/usr/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
  LD_LIBRARY_PATH="$native/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export LIBRARY_PATH LD_LIBRARY_PATH
}

use_llvm() {
  case "$1" in
    21) LLVM_ROOT="$(llvm21_root)" ;;
    23) LLVM_ROOT="$(llvm23_root)" ;;
    system) LLVM_ROOT="/usr" ;;
    *) die "unknown llvm mode: $1" ;;
  esac
  [ -x "$LLVM_ROOT/bin/llvm-config" ] || die "llvm-config missing under $LLVM_ROOT"
  export LLVM_ROOT
}

install_prefix_runtime() {
  prefix="$1"
  native="$(native_unwind_root)"
  sys="$prefix/lib/rustlib/$TARGET/lib"
  [ -d "$sys" ] || die "sysroot lib directory missing: $sys"
  [ -f "$native/usr/lib/libunwind.a" ] || die "native libunwind.a missing: $native"
  [ -f "$native/usr/lib/libunwind.so.1.0" ] || die "native libunwind.so.1.0 missing: $native"

  cp -f "$native/usr/lib/libunwind.so.1.0" "$sys/libunwind.so.1.0"
  ln -sfn libunwind.so.1.0 "$sys/libunwind.so.1"
  ln -sfn libunwind.so.1 "$sys/libunwind.so"

  cp -f "$native/usr/lib/libunwind.so.1.0" "$prefix/lib/libunwind.so.1.0"
  ln -sfn libunwind.so.1.0 "$prefix/lib/libunwind.so.1"
  ln -sfn libunwind.so.1 "$prefix/lib/libunwind.so"

  self="$sys/self-contained"
  mkdir -p "$self"
  for f in rcrt1.o crt1.o Scrt1.o crti.o crtn.o libc.a; do
    [ -f "/usr/lib/$f" ] || die "declared host musl-dev file missing: /usr/lib/$f"
    cp -f "/usr/lib/$f" "$self/$f"
  done
  crt="$native/usr/lib/llvm23/lib/clang/23/lib/x86_64-alpine-linux-musl"
  [ -f "$crt/clang_rt.crtbegin-x86_64.o" ] || die "compiler-rt crtbegin missing: $crt"
  cp -f "$crt/clang_rt.crtbegin-x86_64.o" "$self/crtbeginS.o"
  cp -f "$crt/clang_rt.crtend-x86_64.o" "$self/crtendS.o"
  cp -f "$native/usr/lib/libunwind.a" "$self/libunwind.a"
}

prefix_sysroot() {
  prefix="$1"
  "$prefix/bin/rustc" --print sysroot 2>/dev/null || true
}

prefix_host() {
  prefix="$1"
  "$prefix/bin/rustc" -vV 2>/dev/null | sed -n 's/^host: //p' | head -n1
}

verify_prefix() {
  stage="$1"
  prefix="$(stage_prefix "$stage")"
  [ -d "$prefix" ] || { echo "missing prefix: $prefix"; return 1; }
  [ -x "$prefix/bin/rustc" ] || { echo "missing rustc: $prefix/bin/rustc"; return 1; }
  [ -x "$prefix/bin/cargo" ] || { echo "missing cargo: $prefix/bin/cargo"; return 1; }
  host="$(prefix_host "$prefix")"
  [ -n "$host" ] || { echo "rustc -vV failed: $prefix/bin/rustc"; return 1; }
  [ "$host" = "$TARGET" ] || { echo "host mismatch: $host != $TARGET"; return 1; }
  version="$(stage_version "$stage")"
  got="$("$prefix/bin/rustc" --version 2>/dev/null || true)"
  case "$got" in
    "rustc $version"*) ;;
    *) echo "version mismatch: expected $version, got ${got:-<none>}"; return 1 ;;
  esac
  sysroot="$(prefix_sysroot "$prefix")"
  [ -d "$sysroot/lib/rustlib/$TARGET/lib" ] || { echo "missing sysroot lib: $sysroot/lib/rustlib/$TARGET/lib"; return 1; }
  ls "$sysroot/lib/rustlib/$TARGET/lib"/libstd-*.rlib >/dev/null 2>&1 || { echo "missing libstd rlib"; return 1; }
  ls "$prefix/lib"/librustc_driver-*.so >/dev/null 2>&1 || { echo "missing rustc driver"; return 1; }
  "$prefix/bin/cargo" --version >/dev/null 2>&1 || { echo "cargo does not run"; return 1; }
  return 0
}

verify_seed_tools() {
  bin="$BUILDS/seed/mrustc-0.12.0/bin"
  [ -x "$bin/mrustc" ] || { echo "missing mrustc"; return 1; }
  [ -x "$bin/minicargo" ] || { echo "missing minicargo"; return 1; }
  "$bin/mrustc" --version >/dev/null 2>&1 || "$bin/mrustc" -V >/dev/null 2>&1 || { echo "mrustc does not run"; return 1; }
  return 0
}

verify_stage() {
  stage="$1"
  case "$stage" in
    seed) verify_seed_tools ;;
    seed-1.90)
      prefix="$(stage_prefix seed-1.90)"
      [ -x "$prefix/bin/rustc" ] || { echo "missing seed rustc"; return 1; }
      [ -x "$prefix/bin/cargo" ] || { echo "missing seed cargo"; return 1; }
      "$prefix/bin/rustc" --version 2>/dev/null | grep -q '^rustc 1\.90\.0' || { echo "seed rustc version mismatch"; return 1; }
      "$prefix/bin/cargo" --version 2>/dev/null | grep -q '^cargo 1\.90\.0' || { echo "seed cargo version mismatch"; return 1; }
      sysroot="$("$prefix/bin/rustc" --print sysroot 2>/dev/null || true)"
      [ -d "$sysroot/lib/rustlib/$TARGET/lib" ] || { echo "seed sysroot missing"; return 1; }
      ;;
    *) verify_prefix "$stage" ;;
  esac
}

stage_state() {
  stage="$1"
  if verify_stage "$stage" >/dev/null 2>&1; then
    echo "passed"
    return 0
  fi
  recorded="$(state_get "$stage")"
  case "$recorded" in
    failed) echo "failed" ;;
    running) echo "incomplete" ;;
    *) 
      prefix="$(stage_prefix "$stage")"
      if [ -e "$prefix" ] || [ -e "$BUILDS/$stage" ] || [ -e "$ARTIFACTS/$stage" ]; then
        echo "incomplete"
      else
        echo "not-attempted"
      fi
      ;;
  esac
}

require_stage() {
  stage="$1"
  verify_stage "$stage" >/dev/null 2>&1 || die "prerequisite stage not built: $stage"
}

run_stage() {
  stage="$1"
  shift
  log="$LOGS/$stage/build.log"
  mkdir -p "$(dirname "$log")"
  state_write "$stage" running "$*"
  note "stage $stage: $*"
  if "$@" >>"$log" 2>&1; then
    if verify_stage "$stage"; then
      state_write "$stage" passed "$log"
      note "stage $stage passed"
      return 0
    fi
    state_write "$stage" failed "verification failed"
    echo "genesis: stage $stage built but verification failed; see $log" >&2
    return 1
  else
    rc=$?
  fi
  state_write "$stage" failed "command exited $rc"
  echo "genesis: stage $stage failed (exit $rc); see $log" >&2
  return "$rc"
}

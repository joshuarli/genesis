#!/bin/sh
# Build mrustc and minicargo from the pinned source.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

clear_rust_environment
setup_ccache "${GENESIS_CCACHE_NAMESPACE:-dev}" || true

SRC="$BUILDS/seed/mrustc-0.12.0"
ARCHIVE="$DOWNLOADS/mrustc-0.12.0.tar.gz"
if [ ! -f "$SRC/Makefile" ]; then
  download_source mrustc "$ARCHIVE"
  mkdir -p "$BUILDS/seed"
  extract_archive "$ARCHIVE" "$BUILDS/seed" "$SRC/Makefile"
fi

cd "$SRC"
if [ ! -f "$SRC/.genesis-patched" ]; then
  apply_patch "$ROOT/patches/mrustc/patch.patch"
  apply_patch "$ROOT/patches/mrustc/aea331a4f60535eb6c146b82c50255334e4abf3a.patch"
  apply_patch "$ROOT/patches/mrustc/mrustc-undefined-behavior.patch"
  if ! grep -q "inline static const unsigned PTR_BASE" src/hir/encoded_literal.hpp; then
    sed -i s/"static const unsigned PTR_BASE"/"inline static const unsigned PTR_BASE"/ src/hir/encoded_literal.hpp
  fi
  touch "$SRC/.genesis-patched"
fi

CXX_BIN="$(ccache_cxx)"
if command -v ccache >/dev/null 2>&1; then
  export MRUSTC_CCACHE=1
fi
note "mrustc C++ compiler: $CXX_BIN"
make -j"$JOBS" CXX="$CXX_BIN" CXXFLAGS="-g0 -O2"
make -f minicargo.mk bin/minicargo

verify_seed_tools
echo "SEED_TOOLS_OK"

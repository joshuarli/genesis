#!/bin/sh
# S8 ccache environment: project-namespaced C/C++ object cache.
# Source this for any future build run (S9/S10): `. scripts/ccache-env.sh`.
# Three consumers (per recipe):
#   1. mrustc C++ build:  make CXX="ccache c++"   (or CXX="ccache g++")
#   2. mrustc-generated C: export MRUSTC_CCACHE=1  (honored by build-*.sh)
#   3. source-built LLVM/native deps (cmake): -DCMAKE_C_COMPILER_LAUNCHER=ccache
#      -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
# Namespaces: ccach-dev (this file) for development; replay uses a fresh
# CCACHE_DIR (S10) so lineage never mixes. Never point at ~/.cache (shared).
if [ -z "${CCACHE_DIR:-}" ]; then
  TOP="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$TOP" ]; then
    CCACHE_DIR_DEFAULT="$TOP/.work/cache/ccache-dev"
  else
    D="$(dirname "$0")"
    case "$D" in
      *scripts) CCACHE_DIR_DEFAULT="$D/../.work/cache/ccache-dev" ;;
      *) echo "ccache-env: run from repo root or set CCACHE_DIR" >&2; return 1 2>/dev/null || exit 1 ;;
    esac
  fi
  export CCACHE_DIR="$CCACHE_DIR_DEFAULT"
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

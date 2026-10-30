#!/bin/sh
# S8 cache stats: project ccache namespace counters and disk use.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CCACHE_DIR="${CCACHE_DIR:-$ROOT/.work/cache/ccache-dev}"
echo "=== ccache stats ($CCACHE_DIR) ==="
ccache -s
echo "=== disk ==="
du -sh "$CCACHE_DIR" 2>/dev/null || echo "(empty/missing)"
df -h "$ROOT/.work" | tail -n1
echo "=== config ==="
cat "${CCACHE_CONFIGPATH:-$CCACHE_DIR/ccache.conf}" 2>/dev/null || echo "(no config file)"

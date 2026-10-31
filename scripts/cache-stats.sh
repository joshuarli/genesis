#!/bin/sh
# Show project ccache counters and disk use.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../recipes/common.sh"
export CCACHE_DIR="${CCACHE_DIR:-$CACHE/ccache-dev}"
echo "=== ccache stats ($CCACHE_DIR) ==="
if command -v ccache >/dev/null 2>&1; then ccache -s; else echo "ccache not installed"; fi
echo "=== disk ==="
du -sh "$CCACHE_DIR" 2>/dev/null || echo "(empty/missing)"
df -h "$WORK" | tail -n1
echo "=== config ==="
cat "${CCACHE_CONFIGPATH:-$CCACHE_DIR/ccache.conf}" 2>/dev/null || echo "(no config file)"

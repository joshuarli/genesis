#!/bin/sh
# Development ccache environment. Recipes call setup_ccache automatically.
# Usage: . scripts/ccache-env.sh [namespace]
set -eu
GENESIS_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export GENESIS_ROOT
. "$GENESIS_ROOT/recipes/common.sh"
setup_ccache "${1:-dev}"

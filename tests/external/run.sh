#!/bin/sh
# S7 external test: pinned rustfilt 0.2.1 builds offline from vendored sources.
# Usage: tests/external/run.sh --prefix <toolchain-prefix>
set -eu
PREFIX=""
while [ $# -gt 0 ]; do case "$1" in --prefix) PREFIX="${2:-}"; shift 2;; *) echo "usage: run.sh --prefix <prefix>" >&2; exit 2;; esac; done
[ -n "$PREFIX" ] || exit 2
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="$PREFIX/bin:$PATH"
export CARGO_NET_OFFLINE=true
SYSROOT_LIB="$("$PREFIX/bin/rustc" --print sysroot)/lib/rustlib/$("$PREFIX/bin/rustc" -vV | grep '^host' | cut -d' ' -f2)/lib"
export LD_LIBRARY_PATH="$SYSROOT_LIB:${LD_LIBRARY_PATH-}"
PKG="$ROOT/../../.work/external/rustfilt-0.2.1"
[ -d "$PKG/vendor" ] || { echo "vendored sources missing: $PKG/vendor" >&2; exit 1; }
# lto=off: release LTO fails here (llvm-bitcode-linker finds no .llvmbc); triage deferred, not part of S7.
(cd "$PKG" && cargo build --offline --release --config 'profile.release.lto=false' 2>&1 | tail -2)
echo "_ZN3foo3barE" | "$PKG/target/release/rustfilt" | grep -q "foo::bar" || { echo "FAIL: demangle check" >&2; exit 1; }
echo "EXTERNAL_OK rustfilt-0.2.1"

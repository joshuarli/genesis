#!/bin/sh
# Build the 1.90.0 seed rustc and cargo with mrustc/minicargo.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

require_stage seed
clear_rust_environment
setup_ccache "${GENESIS_CCACHE_NAMESPACE:-dev}" || true

A="$ARTIFACTS/seed-1.90"
M="$BUILDS/seed/mrustc-0.12.0"
TARGET="x86_64-unknown-linux-musl"

extract_native_group llvm21 "$A/llvm21"
extract_native_group unwind "$A/native"
LLVM21="$(llvm21_root)"
[ -x "$LLVM21/bin/llvm-config" ] || die "llvm21 extraction incomplete"

SHIM_DIR="$A/tls-shim"
mkdir -p "$SHIM_DIR"
cc -shared -fPIC -O2 -o "$SHIM_DIR/tlskeys.so" "$ROOT/support/tlskeys.c" -ldl
[ -f "$SHIM_DIR/tlskeys.so" ] || die "TLS shim build failed"

ARCHIVE="$DOWNLOADS/rustc-1.90.0-src.tar.gz"
download_source rust1_90_0 "$ARCHIVE"
cp -f "$ARCHIVE" "$M/"
RUSTC_SRC="$M/rustc-1.90.0-src"
if [ ! -f "$RUSTC_SRC/extracted" ]; then
  (cd "$M" && tar -xzf rustc-1.90.0-src.tar.gz)
  touch "$RUSTC_SRC/extracted"
fi

NATIVE="$A/native"
CRT_DIR="$NATIVE/usr/lib/llvm23/lib/clang/23/lib/x86_64-alpine-linux-musl"
SELF="$M/self-contained"
mkdir -p "$SELF"
for f in rcrt1.o crt1.o Scrt1.o crti.o crtn.o libc.a; do
  [ -f "/usr/lib/$f" ] || die "missing declared host musl-dev file: /usr/lib/$f"
  cp -f "/usr/lib/$f" "$SELF/"
done
[ -d "$CRT_DIR" ] || die "compiler-rt CRT directory missing: $CRT_DIR"
cp -f "$CRT_DIR/clang_rt.crtbegin-x86_64.o" "$SELF/crtbeginS.o"
cp -f "$CRT_DIR/clang_rt.crtend-x86_64.o" "$SELF/crtendS.o"
cp -f "$NATIVE/usr/lib/libunwind.a" "$SELF/"
for prefix in prefix-s prefix-2 prefix; do
  d="$M/run_rustc/output/$prefix/lib/rustlib/$TARGET/lib"
  mkdir -p "$d"
  ln -sfn "$SELF" "$d/self-contained"
done

if ! grep -q 'RUSTFLAGS="-Ctarget-feature=-crt-static ' "$M/run_rustc/Makefile"; then
  sed -i s/'RUSTFLAGS="'/'RUSTFLAGS="-Ctarget-feature=-crt-static '/ "$M/run_rustc/Makefile"
fi

export RUSTC_TARGET="$TARGET"
export RUSTC_VERSION=1.90.0
export RUSTC_INSTALL_BINDIR=bin
export OUTDIR_SUF=
export MRUSTC_TARGET_VER=1.90
export LLVM_CONFIG="$LLVM21/bin/llvm-config"
export CCC_OVERRIDE_OPTIONS="+-g0"
export CARGO_CFG_RUSTIX_NO_LINUX_RAW=1
export LD_PRELOAD="$SHIM_DIR/tlskeys.so"
export LD_LIBRARY_PATH="$LLVM21/usr/lib:$NATIVE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBRARY_PATH="$NATIVE/usr/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
if command -v ccache >/dev/null 2>&1; then
  export MRUSTC_CCACHE=1
fi

cd "$M"
note "seed llvm: $($LLVM_CONFIG --version)"
make RUSTCSRC
rm -rf "$RUSTC_SRC/build"
ln -s "$LLVM21" "$RUSTC_SRC/build"
printf 'all:\n' > "$RUSTC_SRC/build/Makefile"
make -f minicargo.mk PARLEVEL="$PARLEVEL" output/rustc
make -f minicargo.mk PARLEVEL="$PARLEVEL" output/cargo
attempt=5
while [ "$attempt" -ne 0 ]; do
  make -C run_rustc "output/prefix-s/lib/rustlib/$TARGET/lib/libstd.rlib" || true
  attempt=$((attempt - 1))
done
make -C run_rustc PARLEVEL="$PARLEVEL"

INSTALL="$A/install"
mkdir -p "$INSTALL"
cp -R run_rustc/output/prefix/. "$INSTALL/"
if [ -L "$INSTALL/lib/rustlib/$TARGET/lib/self-contained" ]; then
  rm -f "$INSTALL/lib/rustlib/$TARGET/lib/self-contained"
fi
install_prefix_runtime "$INSTALL"
cat > "$INSTALL/bin/rustc" <<'EOF'
#!/bin/sh
d=$(dirname "$0")
LD_LIBRARY_PATH="$d/../lib:$d/../lib/rustlib/x86_64-unknown-linux-musl/lib" "$d/rustc_binary" "$@"
EOF
chmod +x "$INSTALL/bin/rustc"
[ -x "$INSTALL/bin/rustc_binary" ] || die "seed rustc_binary missing from install"
"$INSTALL/bin/rustc" --version
"$INSTALL/bin/cargo" --version
echo "SEED_RUST_OK"

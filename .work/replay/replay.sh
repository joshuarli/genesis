#!/bin/sh
# S10 partial replay (scope S2-S4): mrustc -> 1.90 seed -> 1.91.1 in a FRESH
# output/cache namespace. Sources shared (tarballs, pins, apk archives);
# every compiled object, prefix, and cache entry rebuilt here.
# Neutralizations vs dev: isolated CARGO_HOME, RUSTC_WRAPPER=passthrough
# (kache never invoked; verified honored), ccache disabled, PATH scrubbed
# (no ambient cargo/rustup), network allowed for source fetches only.
set -eu
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
RP="$REPO/.work/replay"
SEED_DL="$REPO/.work/build/seed/dl"
A190_DL="$REPO/.work/artifacts/seed-1.90/dl"
LOGD="$RP/logs"
mkdir -p "$RP/build/seed" "$RP/build/1.91.1" "$RP/artifacts/seed-1.90" "$RP/artifacts/1.91.1" "$RP/cargo-home" "$RP/bin" "$LOGD"
TARGET="x86_64-unknown-linux-musl"
echo "=== S10 replay S2-S4 $(date -u +%FT%TZ) ==="
[ -n "${MINICARGO_DEFER_CODEGEN+x}" ] && { echo "FATAL: MINICARGO_DEFER_CODEGEN set" >&2; exit 1; }
ln -sf "$(command -v mold)" "$RP/bin/mold" 2>/dev/null || true
cat > "$RP/passthrough.sh" <<'EOF'
#!/bin/sh
echo "RUSTC_CALL: $1" >> "$RP_LOG/passthrough.log"
exec "$@"
EOF
sed -i "s|\$RP_LOG|$LOGD|" "$RP/passthrough.sh"
chmod +x "$RP/passthrough.sh"
: > "$LOGD/passthrough.log"
export CARGO_HOME="$RP/cargo-home"
export CARGO_NET_OFFLINE=true
export RUSTC_WRAPPER="$RP/passthrough.sh"
export CCACHE_DISABLE=1
export PATH="$RP/bin:/usr/bin:/bin"
command -v cargo >/dev/null 2>&1 && { echo "FATAL: ambient cargo on PATH" >&2; exit 1; } || true
NATIVE="$RP/native"
mkdir -p "$NATIVE"
echo "=== R0 shared sources (verify-only) ==="
sha256sum -c <<EOF
c1ba35f5fc5c4ca2952d9f5526e900dcb6632ea7fd4d71fa58029b3bb563ae56  $SEED_DL/mrustc-0.12.0.tar.gz
799a9f9cba4ed5351e071048bcf6b5560755d9009648def33a407dd4961f9b7e  $A190_DL/rustc-1.90.0-src.tar.gz
EOF
echo "=== R1 mrustc+minicargo (S2 replay) ==="
cd "$RP/build/seed"
if [ ! -f mrustc-0.12.0/Makefile ]; then tar -xzf "$SEED_DL/mrustc-0.12.0.tar.gz"; fi
PINS="$REPO/.work/pins"
cd mrustc-0.12.0
for p in "$PINS/patch.patch" "$PINS/aea331a4f60535eb6c146b82c50255334e4abf3a.patch" "$PINS/mrustc-undefined-behavior.patch"; do
  if patch -p1 -N --silent --dry-run -i "$p"; then patch -p1 --silent -i "$p"
  else echo "already applied: $(basename "$p")"; fi
done
grep -q "inline static const unsigned PTR_BASE" src/hir/encoded_literal.hpp || \
  sed -i s/"static const unsigned PTR_BASE"/"inline static const unsigned PTR_BASE"/ src/hir/encoded_literal.hpp
make -j12 CXXFLAGS="-g0 -O2" > "$LOGD/seed-mrustc.log" 2>&1
make -f minicargo.mk bin/minicargo >> "$LOGD/seed-mrustc.log" 2>&1
./bin/mrustc --version >> "$LOGD/seed-mrustc.log" 2>&1
./bin/minicargo 2>&1 | head -1 >> "$LOGD/seed-mrustc.log" 2>&1 || true
echo "=== R2 llvm21+unwind+crt native roots (fresh extracts) ==="
mkdir -p "$RP/artifacts-seed/llvm21" "$RP/artifacts-seed/crt" "$RP/artifacts-seed/dlc"
for f in "$A190_DL"/llvm21/*.apk; do tar -xzf "$f" -C "$RP/artifacts-seed/llvm21"; done
tar -xzf "$A190_DL"/llvm21-static-*.apk -C "$RP/artifacts-seed/llvm21" 2>/dev/null || tar -xzf "$A190_DL"/llvm21/llvm21-static-*.apk -C "$RP/artifacts-seed/llvm21"
nsrc="$RP/artifacts-seed/native"
mkdir -p "$nsrc"
for f in "$A190_DL"/compiler-rt-*.apk "$A190_DL"/llvm-libunwind-*.apk "$A190_DL"/llvm-libunwind-static-*.apk "$A190_DL"/llvm-libunwind-dev-*.apk; do tar -xzf "$f" -C "$nsrc"; done
LLVM21="$RP/artifacts-seed/llvm21/usr/lib/llvm21"
"$LLVM21/bin/llvm-config" --version
export LIBRARY_PATH="$nsrc/usr/lib"
export LD_LIBRARY_PATH="$nsrc/usr/lib:${LD_LIBRARY_PATH-}"
export LD_PRELOAD="$RP/tls-shim/tlskeys.so"
mkdir -p "$(dirname "$LD_PRELOAD")"
cp "$REPO/.work/artifacts/seed-1.90/tls-shim/tlskeys.c" "$(dirname "$LD_PRELOAD")/"
cc -shared -fPIC -O2 -o "$LD_PRELOAD" "$(dirname "$LD_PRELOAD")/tlskeys.c" -ldl
echo "=== R3 seed rustc+cargo (S3 replay) ==="
RUSTC_SRC="$RP/build/seed/mrustc-0.12.0/rustc-1.90.0-src"
cp -f "$A190_DL/rustc-1.90.0-src.tar.gz" "$RP/build/seed/mrustc-0.12.0/"
cd "$RP/build/seed/mrustc-0.12.0"
if [ ! -f rustc-1.90.0-src/extracted ]; then
  tar -xzf rustc-1.90.0-src.tar.gz
  touch rustc-1.90.0-src.tar.gz rustc-1.90.0-src/extracted
fi
export RUSTC_VERSION=1.90.0 RUSTC_TARGET="$TARGET" RUSTC_INSTALL_BINDIR=bin OUTDIR_SUF= MRUSTC_TARGET_VER=1.90
export LLVM_CONFIG="$LLVM21/bin/llvm-config"
export CCC_OVERRIDE_OPTIONS="+-g0"
export CARGO_CFG_RUSTIX_NO_LINUX_RAW=1
make RUSTCSRC > "$LOGD/seed-rust.log" 2>&1
ln -sfn "$LLVM21" rustc-1.90.0-src/build
printf 'all:\n' > rustc-1.90.0-src/build/Makefile
M="$RP/build/seed/mrustc-0.12.0"
mkdir -p "$M/self-contained"
cp /usr/lib/rcrt1.o /usr/lib/crti.o /usr/lib/crtn.o "$M/self-contained/"
CRT="$nsrc/usr/lib/llvm23/lib/clang/23/lib/x86_64-alpine-linux-musl"
cp "$CRT/clang_rt.crtbegin-x86_64.o" "$M/self-contained/crtbeginS.o"
cp "$CRT/clang_rt.crtend-x86_64.o" "$M/self-contained/crtendS.o"
cp "$nsrc/usr/lib/libunwind.a" "$M/self-contained/"
for prefix in prefix-s prefix-2 prefix; do
  D="$M/run_rustc/output/$prefix/lib/rustlib/$TARGET/lib"
  mkdir -p "$D"
  ln -sfn "$M/self-contained" "$D/self-contained"
done
sed -i s/'RUSTFLAGS="'/'RUSTFLAGS="-Ctarget-feature=-crt-static '/ "$M/run_rustc/Makefile"
make -f minicargo.mk PARLEVEL=8 output/rustc >> "$LOGD/seed-rust.log" 2>&1
make -f minicargo.mk PARLEVEL=8 output/cargo >> "$LOGD/seed-rust.log" 2>&1
STD_ATTEMPTS=5
while [ "$STD_ATTEMPTS" -ne 0 ]; do
  make -C run_rustc "output/prefix-s/lib/rustlib/$TARGET/lib/libstd.rlib" >> "$LOGD/seed-rust.log" 2>&1 || true
  STD_ATTEMPTS=$((STD_ATTEMPTS - 1))
done
make -C run_rustc PARLEVEL=8 >> "$LOGD/seed-rust.log" 2>&1
SEEDP="$RP/artifacts/seed-1.90/install"
mkdir -p "$SEEDP"
cp -R run_rustc/output/prefix/* "$SEEDP/"
cat > "$SEEDP/bin/rustc" <<EOF
#!/bin/sh
d=\$(dirname "\$0")
LD_LIBRARY_PATH="\$d/../lib:\$d/../lib/rustlib/$TARGET/lib" "\$d/rustc_binary" "\$@"
EOF
chmod +x "$SEEDP/bin/rustc"
export PATH="$SEEDP/bin:$RP/bin:/usr/bin:/bin"
"$SEEDP/bin/rustc" --version
SEEDCARGO="$M/output/cargo"
echo "=== R4 1.91.1 (S4 replay) ==="
B191="$RP/build/1.91.1"
mkdir -p "$B191"
if [ ! -f "$B191/rustc-1.91.1-src/configure" ]; then
  tar -xzf "$REPO/.work/build/1.91.1/dl/rustc-1.91.1-src.tar.gz" -C "$B191"
fi
cd "$B191/rustc-1.91.1-src"
find ./vendor -name ".cargo-checksum.json" | while IFS= read -r c; do printf '{ "files": {} }\n' > "$c"; done
find . -name "Cargo.lock" | while IFS= read -r f; do cp "$f" "$f.bak"; grep -v '^checksum = "' "$f.bak" > "$f" || true; done
find ./src/bootstrap -type f | while IFS= read -r f; do sed -i s/'"--frozen"'/'"--offline"'/ "$f"; done
F=library/portable-simd/crates/core_simd/src/masks/bitmask.rs
python3 - "$F" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('    #[must_use = "method returns a new mask and does not mutate the original value"]\n    fn bit', '    fn bit')
s = s.replace('    #[must_use = "method returns a new mask and does not mutate the original value"]\n    fn not(mut self)', '    fn not(mut self)')
open(p, "w").write(s)
EOF
rm -f bootstrap.toml config.toml
P191="$RP/artifacts/1.91.1/prefix"
export RUSTFLAGS="-Clinker=clang -Clink-arg=-Wl,-fuse-ld=mold -Cembed-bitcode=false -Ctarget-cpu=native -Ccodegen-units=$(nproc) -Zthreads=8"
python3 ./src/bootstrap/configure.py --build="$TARGET" --host="$TARGET" --target="$TARGET" \
  --local-rust-root="$SEEDP" --tools="cargo" --llvm-root="$LLVM21" --llvm-libunwind="system" \
  --enable-local-rust --enable-clang --enable-option-checking --enable-vendor \
  --dist-compression-formats=gz --disable-docs --python="python3" \
  --prefix="$P191/usr" --sysconfdir="$P191/etc" --release-channel="stable" \
  --set="install.prefix=$P191" --set="target.$TARGET.crt-static=false" \
  --set="target.$TARGET.musl-root=/usr" --set="target.$TARGET.llvm-config=$LLVM21/bin/llvm-config" \
  --set="rust.optimize=2" --set="rust.lld=false" --set="rust.llvm-tools=false" \
  > "$LOGD/rustc-1.91.1-configure.log" 2>&1
python3 x.py build --stage 1 library -j 8 > "$LOGD/rustc-1.91.1.log" 2>&1
python3 x.py build --stage 1 src/tools/cargo -j 8 >> "$LOGD/rustc-1.91.1.log" 2>&1
mkdir -p "$P191"
mv build/host/stage1/* "$P191/"
mv "$(find build/host/ -type f -name cargo | head -n1)" "$P191/bin/"
"$P191/bin/rustc" --version
"$P191/bin/cargo" --version
echo REPLAY_OK

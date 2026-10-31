#!/bin/sh
# Build one Rust release with its pinned predecessor through x.py.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

STAGE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) STAGE="${2:-}"; shift 2 ;;
    *) die "usage: build-rust.sh --stage <stage>" ;;
  esac
done
[ -n "$STAGE" ] || die "usage: build-rust.sh --stage <stage>"
stage_exists "$STAGE" || die "unknown release stage: $STAGE"
[ "$STAGE" != "seed" ] && [ "$STAGE" != "seed-1.90" ] || die "build-rust.sh handles release stages only"

SOURCE_KEY="$(release_field "$STAGE" source)"
VERSION="$(stage_version "$STAGE")"
PREDECESSOR_STAGE="$(release_field "$STAGE" predecessor)"
MODE="$(release_field "$STAGE" mode)"
LLVM_MODE="$(release_field "$STAGE" llvm)"
TOOLS="$(release_field "$STAGE" tools)"
PATCH="$(release_field "$STAGE" patch)"
ARTIFACT="$(release_field "$STAGE" artifact)"
B="$BUILDS/$ARTIFACT"
PREFIX="$ARTIFACTS/$ARTIFACT/prefix"

require_stage "$PREDECESSOR_STAGE"
PRED="$(stage_prefix "$PREDECESSOR_STAGE")"
[ -x "$PRED/bin/rustc" ] || die "predecessor rustc missing: $PRED"

clear_rust_environment
setup_ccache "${GENESIS_CCACHE_NAMESPACE:-dev}" || true
use_native_unwind_runtime
use_llvm "$LLVM_MODE"

ARCHIVE="$DOWNLOADS/$(source_field "$SOURCE_KEY" file)"
download_source "$SOURCE_KEY" "$ARCHIVE"
mkdir -p "$B"
SRC="$B/rustc-$VERSION-src"
if [ ! -f "$SRC/configure" ]; then
  extract_archive "$ARCHIVE" "$B" "$SRC/configure"
  [ -d "$SRC" ] || die "source archive did not produce $SRC"
fi

cd "$SRC"
note "surgery $VERSION"
find ./vendor -name .cargo-checksum.json -type f | while IFS= read -r c; do
  printf '{ "files": {} }\n' > "$c"
done
find . -name Cargo.lock -type f | while IFS= read -r f; do
  if [ ! -f "$f.bak" ]; then
    cp "$f" "$f.bak"
  fi
  grep -v '^checksum = "' "$f.bak" > "$f" || true
done
find ./src/bootstrap -type f | while IFS= read -r f; do
  sed -i s/'"--frozen"'/'"--offline"'/ "$f"
done

if [ -n "$PATCH" ]; then
  apply_patch "$ROOT/$PATCH"
fi
if [ "$MODE" = "final" ]; then
  note "musl default-link policy: dynamic"
  find ./compiler/rustc_target/src/spec/targets/ -type f 2>/dev/null | grep -i musl | while IFS= read -r f; do
    sed -i s/"crt_static_default = true"/"crt_static_default = false"/ "$f" || true
  done
fi

MOLD_DIR="$(dirname "$(command -v mold)")"
export PATH="$PRED/bin:$MOLD_DIR:/usr/bin:/bin"
export CC=cc CXX=c++ HOST_CC=cc HOST_CXX=c++
command -v clang >/dev/null || die "clang missing"
command -v mold >/dev/null || die "mold missing"

RUSTFLAGS_LOCAL="-Clinker=clang -Clink-arg=-Wl,-fuse-ld=mold -Cembed-bitcode=false -Ctarget-cpu=native -Ccodegen-units=$(nproc) -Zthreads=8"
MAJOR=$(printf '%s' "$VERSION" | cut -d. -f2)
if [ "$MAJOR" -lt 93 ]; then
  RUSTFLAGS_LOCAL="$RUSTFLAGS_LOCAL -Ctarget-feature=-avx512f"
fi
export RUSTFLAGS="$RUSTFLAGS_LOCAL"
if [ "$LLVM_MODE" = "23" ]; then
  export RUST_MIN_STACK=16777216
fi
export LLVM_CONFIG="$LLVM_ROOT/bin/llvm-config"

note "configure $VERSION (predecessor $PREDECESSOR_STAGE, llvm $LLVM_MODE, mode $MODE)"
rm -f bootstrap.toml config.toml
python3 ./src/bootstrap/configure.py \
  --build="$TARGET" --host="$TARGET" --target="$TARGET" \
  --local-rust-root="$PRED" --tools="$TOOLS" \
  --llvm-root="$LLVM_ROOT" --llvm-libunwind=system \
  --enable-local-rust --enable-clang --enable-option-checking \
  --enable-vendor --dist-compression-formats=gz --disable-docs \
  --python=python3 --prefix="$PREFIX/usr" --sysconfdir="$PREFIX/etc" \
  --release-channel=stable --set="install.prefix=$PREFIX" \
  --set="target.$TARGET.crt-static=false" \
  --set="target.$TARGET.musl-root=/usr" \
  --set="target.$TARGET.llvm-config=$LLVM_ROOT/bin/llvm-config" \
  --set="rust.optimize=2" --set="rust.lld=false" \
  --set="rust.llvm-tools=false"

if [ "$MODE" = "final" ]; then
  note "x.py install $VERSION"
  python3 x.py install -j "$JOBS"
else
  note "x.py build stage 1 library $VERSION"
  python3 x.py build --stage 1 library -j "$JOBS"
  note "x.py build stage 1 cargo $VERSION"
  python3 x.py build --stage 1 src/tools/cargo -j "$JOBS"
  mkdir -p "$PREFIX"
  cp -a build/host/stage1/. "$PREFIX/"
  if [ ! -x "$PREFIX/bin/cargo" ]; then
    for candidate in build/host/stage1-tools-bin/cargo build/host/stage1/bin/cargo; do
      if [ -x "$candidate" ]; then
        cp -a "$candidate" "$PREFIX/bin/cargo"
        break
      fi
    done
  fi
fi

install_prefix_runtime "$PREFIX"
"$PREFIX/bin/rustc" --version
"$PREFIX/bin/cargo" --version
echo "BUILD_${STAGE}_OK"

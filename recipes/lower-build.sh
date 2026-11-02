#!/bin/sh
# Build the StageX lower closure and extend it to Rust 1.99.1.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

LOWER_WORK="${GENESIS_LOWER_WORK:-$WORK/lower/work}"
STAGEX_SRC="$(stagex_source_dir)"
STAGEX_OUT="$STAGEX_SRC/out"
LOWER_LOGS="$WORK/lower/logs"
BUILDER_IMAGE="${GENESIS_LOWER_BUILDER:-genesis/lower-builder:1.96.0}"
PREFIX_1_96="$LOWER_WORK/artifacts/stagex-1.96.0/prefix"
LOWER_STAGES=""
MIN_FREE_GB=512

usage() {
  cat <<'EOF'
usage: recipes/lower-build.sh [--stage STAGE] [--skip-closure] [--skip-tests]

Without options, builds the pinned StageX closure, extracts its 1.96.0
toolchain, builds stagex-1.97.1 through stagex-1.99.1, and runs the same
functional tests against the final StageX-lineage prefix. The build refuses
to start unless at least 512 GB is free on the work and Docker filesystems.
EOF
}

STAGE=""
SKIP_CLOSURE=0
SKIP_TESTS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) STAGE="${2:-}"; shift 2 ;;
    --skip-closure) SKIP_CLOSURE=1; shift ;;
    --skip-tests) SKIP_TESTS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

nearest_dir() {
  path="$1"
  while [ ! -d "$path" ]; do
    path="$(dirname "$path")"
  done
  printf '%s\n' "$path"
}

free_gb() {
  df -P "$1" | awk 'END { print int($4 / 1024 / 1024) }'
}

require_free_space() {
  work_dir="$(nearest_dir "$LOWER_WORK")"
  limit_dir="$work_dir"
  limit_free="$(free_gb "$work_dir")"
  docker_root="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"
  if [ -n "$docker_root" ] && [ -d "$docker_root" ]; then
    docker_free="$(free_gb "$docker_root")"
    if [ "$docker_free" -lt "$limit_free" ]; then
      limit_dir="$docker_root"
      limit_free="$docker_free"
    fi
  fi
  [ "$limit_free" -ge "$MIN_FREE_GB" ] ||
    die "StageX lower build requires at least ${MIN_FREE_GB} GB free; ${limit_dir} has ${limit_free} GB"
}

require_free_space
mkdir -p "$LOWER_WORK" "$LOWER_LOGS"
for stage in $(lower_stages); do
  [ "$(release_field "$stage" mode)" = "external" ] && continue
  LOWER_STAGES="$LOWER_STAGES $stage"
done
[ -n "$LOWER_STAGES" ] || die "no lower release stages pinned in sources.toml"

run_logged() {
  log="$1"
  shift
  mkdir -p "$(dirname "$log")"
  note "run: $*"
  if "$@" >>"$log" 2>&1; then
    return 0
  fi
  rc=$?
  echo "genesis: command failed (exit $rc); see $log" >&2
  tail -n 40 "$log" >&2 || true
  return "$rc"
}

prepare_stagex_git() {
  src="$1"
  if [ ! -d "$src/.git" ]; then
    run_logged "$LOWER_LOGS/stagex-git.log" git -C "$src" init -q
    printf 'out/\nfetch/\n' >> "$src/.git/info/exclude"
    run_logged "$LOWER_LOGS/stagex-git.log" git -C "$src" add -A
    run_logged "$LOWER_LOGS/stagex-git.log" git -C "$src" -c user.email=genesis@local -c user.name=genesis commit -qm "stagex pin $(manifest_field stagex.commit)"
  fi
}

stagex_pkg_value() {
  python3 - "$STAGEX_SRC/packages/core/rust/package.toml" "$1" <<'PY'
import sys
import tomllib
with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
key = sys.argv[2]
if key == "version":
    print(data["package"]["version"])
elif key.startswith("source."):
    print(data["sources"][key.split(".", 1)[1]]["version"])
else:
    raise SystemExit("unknown package field: " + key)
PY
}

core_rust_deps() {
  python3 "$HERE/stagex-closure.py" \
    --stagex-src "$STAGEX_SRC" \
    --target core-rust \
    --commit "$(manifest_field stagex.commit)" |
    awk -F "$(printf '\t')" '$1 == "core-rust" { print $4 }'
}

core_rust_digest() {
  python3 - "$STAGEX_OUT/core-rust/index.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    index = json.load(f)
print(index["manifests"][0]["digest"])
PY
}

prepare_builder_context() {
  run_logged "$LOWER_LOGS/stagex-fetch.log" sh -c "cd '$STAGEX_SRC' && python3 src/fetch.py rust"
  rm -rf "$STAGEX_SRC/packages/core/rust/fetch"
  mkdir -p "$STAGEX_SRC/packages/core/rust/fetch"
  cp -lR "$STAGEX_SRC/fetch/core/rust/." "$STAGEX_SRC/packages/core/rust/fetch/"
}

build_builder_image() {
  version="$(stagex_pkg_value version)"
  mrustc_version="$(stagex_pkg_value source.mrustc)"
  bstr_version="$(stagex_pkg_value source.bstr)"
  deps="$(core_rust_deps)"
  [ -n "$deps" ] || die "core-rust has no resolved dependencies"
  set -- \
    build \
    --target build \
    --tag "$BUILDER_IMAGE" \
    --ulimit nofile=2048:16384 \
    --provenance=false \
    --build-arg SOURCE_DATE_EPOCH=1 \
    --build-arg BUILDKIT_MULTI_PLATFORM=1 \
    --build-arg VERSION="$version" \
    --build-arg VERSION_UNDER="$(printf '%s' "$version" | tr . _)" \
    --build-arg VERSION_DASH="$(printf '%s' "$version" | tr . -)" \
    --build-arg VERSION_MAJOR="$(printf '%s' "$version" | cut -d. -f1)" \
    --build-arg VERSION_MAJOR_MINOR="$(printf '%s' "$version" | cut -d. -f1-2)" \
    --build-arg VERSION_STRIP_SUFFIX="$version" \
    --build-arg MRUSTC_VERSION="$mrustc_version" \
    --build-arg MRUSTC_SOURCE="mrustc-$mrustc_version.tar.gz" \
    --build-arg BSTR_VERSION="$bstr_version" \
    --build-arg BSTR_SOURCE="bstr-$bstr_version.tar.gz" \
    --build-context "fetch=$STAGEX_SRC/fetch/core/rust"
  old_ifs="$IFS"
  IFS=,
  for dep in $deps; do
    set -- "$@" --build-context "stagex/$dep=oci-layout://$STAGEX_OUT/$dep"
  done
  IFS="$old_ifs"
  set -- "$@" \
    --platform=linux/amd64 \
    --progress=plain \
    -f "$STAGEX_SRC/packages/core/rust/Containerfile" \
    "$STAGEX_SRC/packages/core/rust"
  run_logged "$LOWER_LOGS/stagex-rust-builder.log" docker "$@"
}

extract_stagex_1_96() {
  if [ -x "$PREFIX_1_96/bin/rustc" ] && [ -x "$PREFIX_1_96/bin/cargo" ]; then
    return 0
  fi
  mkdir -p "$PREFIX_1_96"
  container="genesis-lower-extract-$$"
  docker create --name "$container" "$BUILDER_IMAGE" >/dev/null
  docker cp "$container:/rootfs/usr/." "$PREFIX_1_96/"
  docker rm "$container" >/dev/null
  docker run --rm -v "$PREFIX_1_96:/out" "$BUILDER_IMAGE" sh -lc '
    set -eu
    mkdir -p /out/lib
    for lib in libz.so.1 libzstd.so.1 libc++.so.1 libc++abi.so.1 libssl.so.3 libcrypto.so.3 libunwind.so.1.0; do
      cp -L "/usr/lib/$lib" /out/lib/
    done
    ln -sfn libunwind.so.1.0 /out/lib/libunwind.so.1
    self=/out/lib/rustlib/x86_64-unknown-linux-musl/lib/self-contained
    mkdir -p "$self"
    for file in rcrt1.o crt1.o Scrt1.o crti.o crtn.o libc.a libunwind.a; do
      cp -L "/usr/lib/$file" "$self/"
    done
  '
  $PREFIX_1_96/bin/rustc --version
  $PREFIX_1_96/bin/cargo --version
}

prepare_native_compat() {
  docker run --rm -v "$LOWER_WORK:/work" "$BUILDER_IMAGE" sh -lc '
    set -eu
    native=/work/artifacts/seed-1.90/native/usr/lib
    crt="$native/llvm23/lib/clang/23/lib/x86_64-alpine-linux-musl"
    mkdir -p "$native" "$crt"
    for file in libunwind.a libunwind.so.1.0 rcrt1.o crt1.o Scrt1.o crti.o crtn.o libc.a; do
      ln -sfn "/usr/lib/$file" "$native/$file"
    done
    crt_dir="$(dirname "$(find /usr/lib/clang -name clang_rt.crtbegin.o -print -quit)")"
    ln -sfn "$crt_dir/clang_rt.crtbegin.o" "$crt/clang_rt.crtbegin-x86_64.o"
    ln -sfn "$crt_dir/clang_rt.crtend.o" "$crt/clang_rt.crtend-x86_64.o"
  '
}

ensure_lower_source() {
  key="$1"
  file="$(source_field "$key" file)"
  archive="$DOWNLOADS/$file"
  download_source "$key" "$archive"
  mkdir -p "$LOWER_WORK/downloads"
  ln -f "$archive" "$LOWER_WORK/downloads/$file"
}

copy_lower_runtime() {
  prefix="$1"
  mkdir -p "$prefix/lib"
  for lib in libz.so.1 libzstd.so.1 libc++.so.1 libc++abi.so.1 libssl.so.3 libcrypto.so.3 libunwind.so.1.0; do
    [ -f "$PREFIX_1_96/lib/$lib" ] || die "StageX runtime library missing: $PREFIX_1_96/lib/$lib"
    cp -f "$PREFIX_1_96/lib/$lib" "$prefix/lib/"
  done
  ln -sfn libunwind.so.1.0 "$prefix/lib/libunwind.so.1"
}

lower_verify() {
  stage="$1"
  GENESIS_ROOT="$ROOT" GENESIS_WORK="$LOWER_WORK" sh -c '. "$GENESIS_ROOT/recipes/common.sh"; verify_stage "$1"' sh "$stage"
}

build_lower_stage() {
  stage="$1"
  source_key="$(release_field "$stage" source)"
  ensure_lower_source "$source_key"
  prepare_native_compat
  if ! run_logged "$LOWER_LOGS/$stage.log" docker run --rm \
      -v "$ROOT:/repo:ro" \
      -v "$LOWER_WORK:/work" \
      -e GENESIS_WORK=/work \
      -e GENESIS_LOWER_BUILD=1 \
      -e GENESIS_JOBS="${GENESIS_JOBS:-8}" \
      -e GENESIS_CXX_JOBS="${GENESIS_CXX_JOBS:-12}" \
      -e GENESIS_PARLEVEL="${GENESIS_PARLEVEL:-8}" \
      -w /repo \
      "$BUILDER_IMAGE" \
      /repo/recipes/build-rust.sh --stage "$stage"; then
    return 1
  fi
  copy_lower_runtime "$LOWER_WORK/artifacts/$(release_field "$stage" artifact)/prefix"
  lower_verify "$stage"
}

run_lower_tests() {
  prefix="$LOWER_WORK/artifacts/stagex-1.99.1/prefix"
  [ -x "$prefix/bin/rustc" ] || die "lower 1.99.1 prefix missing: $prefix"
  mkdir -p "$LOWER_WORK/tests"
  if [ -d "$WORK/external/rustfilt-0.2.1/vendor" ] && [ ! -d "$LOWER_WORK/external/rustfilt-0.2.1" ]; then
    mkdir -p "$LOWER_WORK/external"
    cp -R "$WORK/external/rustfilt-0.2.1" "$LOWER_WORK/external/"
  fi
  run_logged "$LOWER_LOGS/lower-smoke.log" docker run --rm \
    -v "$ROOT:/repo:ro" \
    -v "$LOWER_WORK:/work" \
    -e GENESIS_WORK=/work \
    -w /repo \
    "$BUILDER_IMAGE" \
    /repo/tests/smoke/run.sh --prefix /work/artifacts/stagex-1.99.1/prefix --static
  run_logged "$LOWER_LOGS/lower-external.log" docker run --rm \
    -v "$ROOT:/repo:ro" \
    -v "$LOWER_WORK:/work" \
    -e GENESIS_WORK=/work \
    -w /repo \
    "$BUILDER_IMAGE" \
    /repo/tests/external/run.sh --prefix /work/artifacts/stagex-1.99.1/prefix --work-dir /work/external
}

write_receipt() {
  {
    echo "stagex_commit=$(manifest_field stagex.commit)"
    echo "core_rust_digest=$(core_rust_digest)"
    echo "core_rust_rustc=$("$PREFIX_1_96/bin/rustc" --version)"
    for stage in $LOWER_STAGES; do
      prefix="$LOWER_WORK/artifacts/$(release_field "$stage" artifact)/prefix"
      echo "${stage}_rustc=$("$prefix/bin/rustc" --version)"
    done
    echo "smoke=$(tail -n 1 "$LOWER_LOGS/lower-smoke.log")"
    echo "external=$(tail -n 1 "$LOWER_LOGS/lower-external.log")"
  } > "$LOWER_WORK/consumers-rebuilt"
  cat "$LOWER_WORK/consumers-rebuilt"
}

ensure_stagex_source
prepare_stagex_git "$STAGEX_SRC"

if [ "$SKIP_CLOSURE" = "0" ]; then
  run_logged "$LOWER_LOGS/bootstrap.log" make -C "$STAGEX_SRC" bootstrap
  run_logged "$LOWER_LOGS/core-rust.log" make -C "$STAGEX_SRC" core-rust
fi

[ -f "$STAGEX_OUT/core-rust/index.json" ] || die "StageX core-rust output missing: $STAGEX_OUT/core-rust"
prepare_builder_context
build_builder_image
extract_stagex_1_96

if [ -n "$STAGE" ]; then
  case " $LOWER_STAGES " in
    *" $STAGE "*) ;;
    *) die "unknown lower stage: $STAGE" ;;
  esac
  build_lower_stage "$STAGE"
else
  for stage in $LOWER_STAGES; do
    if lower_verify "$stage" >/dev/null 2>&1; then
      note "stage $stage already complete"
      continue
    fi
    build_lower_stage "$stage"
  done
fi

if [ "$SKIP_TESTS" = "0" ]; then
  run_lower_tests
fi

write_receipt
echo "LOWER_BUILD_OK"

#!/bin/sh
# Fast regression tests for the launcher and test runners. No Rust bootstrap.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BASE="${GENESIS_WORK:-$ROOT/.work}/tmp"
mkdir -p "$BASE"
TMP="$(mktemp -d "$BASE/runner.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM
pass=0
failures=0

ok() { echo "ok: $*"; pass=$((pass + 1)); }
bad() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

expect_fail() {
  name="$1"
  shift
  if "$@" >"$TMP/$name.log" 2>&1; then
    bad "$name: unexpectedly succeeded"
    cat "$TMP/$name.log" >&2
    return 1
  fi
  ok "$name"
}

expect_contains() {
  name="$1"
  file="$2"
  text="$3"
  grep -q "$text" "$file" || { bad "$name: missing '$text'"; cat "$file" >&2; return 1; }
}

FAKE="$TMP/fake-prefix"
SYS="$FAKE/lib/rustlib/x86_64-unknown-linux-musl/lib"
mkdir -p "$FAKE/bin" "$SYS"
printf 'pub fn dummy() {}\n' > "$SYS/libstd-dummy.rlib"
cat > "$FAKE/bin/rustc" <<'EOF'
#!/bin/sh
case "${1:-}" in
  -vV) echo "rustc 1.99.1"; echo "host: x86_64-unknown-linux-musl" ;;
  --print) echo "$FAKE_SYSROOT" ;;
  --version) echo "rustc 1.99.1" ;;
  *) exit 0 ;;
esac
EOF
cat > "$FAKE/bin/cargo" <<'EOF'
#!/bin/sh
echo "intentional compile failure" >&2
exit 42
EOF
chmod +x "$FAKE/bin/rustc" "$FAKE/bin/cargo"
export FAKE_SYSROOT="$FAKE"

SMOKE_WORK="$TMP/stale-work"
mkdir -p "$SMOKE_WORK/target/release"
cat > "$SMOKE_WORK/target/release/pm-user" <<'EOF'
#!/bin/sh
echo "pm ok (stale executable)"
EOF
chmod +x "$SMOKE_WORK/target/release/pm-user"
if "$ROOT/tests/smoke/run.sh" --prefix "$FAKE" --work-dir "$SMOKE_WORK" --only proc-macro-derive >"$TMP/stale.log" 2>&1; then
  bad "stale-executable: compile failure was reported as success"
else
  ok "stale-executable: compile failure stays failed"
fi
expect_contains "stale-executable-status" "$TMP/stale.log" "intentional compile failure"
if grep -q "SMOKE_SUITE_OK" "$TMP/stale.log"; then
  bad "stale-executable: suite marker emitted after failure"
else
  ok "stale-executable: no suite marker"
fi

expect_fail "missing-prefix" "$ROOT/tests/smoke/run.sh" --prefix "$TMP/not-there"
expect_fail "external-vendor-failure" env GENESIS_WORK="$TMP/ext-work" "$ROOT/tests/external/run.sh" --prefix "$FAKE" --work-dir "$TMP/ext-work"
expect_contains "external-vendor-failure-status" "$TMP/external-vendor-failure.log" "cargo vendor failed"

EMPTY_WORK="$TMP/empty-work"
mkdir -p "$EMPTY_WORK"
expect_fail "unknown-stage-build" env GENESIS_WORK="$EMPTY_WORK" "$ROOT/scripts/launch.sh" --until ext-9.99.9
expect_contains "unknown-stage-message" "$TMP/unknown-stage-build.log" "unknown or unsupported stage"
expect_fail "unknown-stage-verify" env GENESIS_WORK="$EMPTY_WORK" "$ROOT/scripts/launch.sh" --verify ext-9.99.9
expect_fail "missing-stage-verify" env GENESIS_WORK="$EMPTY_WORK" "$ROOT/scripts/launch.sh" --verify ext-1.99.1

LOGWORK="$TMP/log-only"
mkdir -p "$LOGWORK/logs/ext-1.99.1"
printf 'Building stage\nCompiling core\n' > "$LOGWORK/logs/ext-1.99.1/build.log"
expect_fail "log-markers-do-not-pass" env GENESIS_WORK="$LOGWORK" "$ROOT/scripts/launch.sh" --verify ext-1.99.1
if grep -q "PASS" "$TMP/log-markers-do-not-pass.log"; then
  bad "log-markers-do-not-pass: printed PASS"
else
  ok "log-markers-do-not-pass: no PASS"
fi

RESUME="$TMP/resume-work"
MARK="$RESUME/artifacts/seed-1.90/install/bin/rustc"
mkdir -p "$(dirname "$MARK")" "$RESUME/build/seed/mrustc-0.12.0"
printf '#!/bin/sh\necho earlier-toolchain\n' > "$MARK"
chmod +x "$MARK"
printf 'KEEP\n' > "$RESUME/build/seed/mrustc-0.12.0/keep.marker"
printf '.genesis-patched\n' > "$RESUME/build/seed/mrustc-0.12.0/.genesis-patched"
cat > "$RESUME/build/seed/mrustc-0.12.0/Makefile" <<'EOF'
all:
	@echo "interrupted make" >&2
	@exit 7
EOF
expect_fail "resume-interrupted-stage" env GENESIS_WORK="$RESUME" "$ROOT/scripts/launch.sh" --until seed
[ -x "$MARK" ] || bad "resume: earlier toolchain was destroyed"
[ -f "$RESUME/build/seed/mrustc-0.12.0/keep.marker" ] || bad "resume: source marker was destroyed"
if [ -x "$MARK" ] && [ -f "$RESUME/build/seed/mrustc-0.12.0/keep.marker" ]; then
  ok "resume: earlier toolchain and partial source survived"
fi
env GENESIS_WORK="$RESUME" "$ROOT/scripts/launch.sh" --status >"$TMP/resume-status.log" 2>&1
expect_contains "status-failed" "$TMP/resume-status.log" "seed"
if grep -q "seed[[:space:]]*failed" "$TMP/resume-status.log"; then
  ok "status: failed stage is distinct from not-attempted"
else
  bad "status: failed stage not reported as failed"
  cat "$TMP/resume-status.log" >&2
fi

STATUS="$TMP/status"
env GENESIS_WORK="$EMPTY_WORK" "$ROOT/scripts/launch.sh" --status >"$STATUS" 2>&1
expect_contains "status-not-attempted" "$STATUS" "not-attempted"
expect_contains "status-stage" "$STATUS" "ext-1.99.1"

STAGEX="$TMP/stagex"
for pkg in bootstrap/stage0 core/filesystem core/busybox core/rust; do
  mkdir -p "$STAGEX/packages/$pkg"
  printf '[package]\nname = "%s"\n' "$(basename "$pkg")" > "$STAGEX/packages/$pkg/package.toml"
done
printf 'FROM scratch AS build\nCOPY --from=stagex/bootstrap-stage0 . /\n' > "$STAGEX/packages/core/filesystem/Containerfile"
printf 'FROM scratch AS build\nCOPY --from=stagex/core-filesystem . /\n' > "$STAGEX/packages/core/busybox/Containerfile"
printf 'FROM scratch AS build\nCOPY --from=stagex/core-busybox . /\n' > "$STAGEX/packages/core/rust/Containerfile"
printf 'FROM scratch AS build\n' > "$STAGEX/packages/bootstrap/stage0/Containerfile"
if python3 "$ROOT/recipes/stagex-closure.py" --stagex-src "$STAGEX" --target core-rust >"$TMP/closure.tsv" 2>&1; then
  ok "stagex-closure: resolved"
else
  bad "stagex-closure: resolver failed"
  cat "$TMP/closure.tsv" >&2
fi
expect_contains "stagex-closure-count" "$TMP/closure.tsv" "packages	4"
expect_contains "stagex-closure-transitive" "$TMP/closure.tsv" "core-filesystem"
rm "$STAGEX/packages/core/filesystem/package.toml"
expect_fail "stagex-closure-missing" python3 "$ROOT/recipes/stagex-closure.py" --stagex-src "$STAGEX" --target core-rust

if [ "$failures" -ne 0 ]; then
  echo "RUNNER_TESTS_FAILED failures=$failures" >&2
  exit 1
fi
echo "RUNNER_TESTS_OK cases=$pass"

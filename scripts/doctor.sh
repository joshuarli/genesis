#!/bin/sh
# Check the declared native build environment and the tracked input manifest.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../recipes/common.sh"

fail() { echo "doctor FAIL: $*" >&2; exit 1; }
info() { echo "doctor: $*"; }
START="$(date +%s)"

for tool in cc c++ clang python3 make tar sha256sum curl ar readelf; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool not found"
done
command -v ccache >/dev/null 2>&1 || fail "ccache not found (declared build environment)"
command -v mold >/dev/null 2>&1 || fail "mold not found (declared build environment)"
command -v docker >/dev/null 2>&1 || info "docker not found (only needed for the parked StageX lower-chain lane)"

[ -f "$SOURCES" ] || fail "input manifest missing: $SOURCES"
python3 "$SOURCES_PY" releases >/dev/null || fail "cannot parse $SOURCES"
python3 "$SOURCES_PY" files | while IFS="$(printf '\t')" read -r file expected; do
  [ -f "$ROOT/$file" ] || fail "tracked input missing: $file"
  actual="$(sha256_of "$ROOT/$file")"
  [ "$actual" = "$expected" ] || fail "tracked input hash mismatch: $file"
done
info "input manifest parse and tracked-file hashes ok"

TMPD="$WORK/tmp/doctor.$$"
trap 'rm -rf "$TMPD"' EXIT INT TERM
mkdir -p "$TMPD"
printf 'int main(void){return 0;}\n' > "$TMPD/c.c"
cc -O2 "$TMPD/c.c" -o "$TMPD/c" || fail "C compile failed"
"$TMPD/c" || fail "C run failed"
info "C probe ok: $(cc --version | head -n1)"
printf '#include <iostream>\nint main(){std::cout<<"ok\\n";return 0;}\n' > "$TMPD/cc.cc"
c++ -O2 "$TMPD/cc.cc" -o "$TMPD/ccx" || fail "C++ compile failed"
[ "$("$TMPD/ccx")" = "ok" ] || fail "C++ run wrong output"
info "C++ probe ok: $(c++ --version | head -n1)"
clang --version | head -n1 | grep -q "23" || fail "clang is not 23.x: $(clang --version | head -n1)"
clang --print-targets 2>/dev/null | grep -qi X86 || fail "clang X86 target missing"
ccache -s >/dev/null 2>&1 || fail "ccache does not run"
mold --version >/dev/null 2>&1 || fail "mold does not run"
info "clang/ccache/mold ok"

for f in /usr/lib/rcrt1.o /usr/lib/crt1.o /usr/lib/Scrt1.o /usr/lib/crti.o /usr/lib/crtn.o /usr/lib/libc.a; do
  [ -f "$f" ] || fail "declared musl-dev file missing: $f"
done
info "musl-dev CRT/archive set ok"

AVAIL_KB="$(df -P "$WORK" | tail -n1 | awk '{print $4}')"
[ "$AVAIL_KB" -gt 20971520 ] || fail "disk available under $WORK <20GB"
info "disk: $(df -h "$WORK" | tail -n1)"
info "cpu/mem: nproc=$(nproc) $(free -g | head -n2 | tr '\n' ' ')"
if [ -r /sys/fs/cgroup/memory.max ]; then info "cgroup memory.max=$(cat /sys/fs/cgroup/memory.max)"; fi
if [ -r /sys/fs/cgroup/cpu.max ]; then info "cgroup cpu.max=$(cat /sys/fs/cgroup/cpu.max)"; fi
if command -v docker >/dev/null 2>&1; then
  docker info >/dev/null 2>&1 || info "docker installed but daemon unavailable (lower-chain lane only)"
fi

END="$(date +%s)"
ELAPSED=$((END - START))
info "elapsed ${ELAPSED}s"
[ "$ELAPSED" -lt 120 ] || fail "doctor took >=120s"
echo "doctor PASS in ${ELAPSED}s"

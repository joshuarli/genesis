#!/bin/sh
# S1 doctor: native C/C++ run, LLVM load, disk/cgroup report, StageX pin record.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PINS="$ROOT/.work/pins/stagex-rust.json"
START="$(date +%s)"
fail() { echo "doctor FAIL: $*" >&2; exit 1; }
info() { echo "doctor: $*"; }
command -v cc >/dev/null 2>&1 || fail "cc not found"
command -v c++ >/dev/null 2>&1 || command -v g++ >/dev/null 2>&1 || command -v clang++ >/dev/null 2>&1 || fail "no C++ compiler found"
command -v clang >/dev/null 2>&1 || fail "clang not found"
command -v docker >/dev/null 2>&1 || fail "docker not found"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"
[ -f "$PINS" ] || fail "pin record missing: $PINS"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT INT TERM
printf 'int main(void){return 0;}\n' > "$TMPD/c.c"
cc -O2 "$TMPD/c.c" -o "$TMPD/c" || fail "C compile failed"
"$TMPD/c" || fail "C run failed (exit $?)"
info "C probe ok: $(cc --version | head -n1)"
printf '#include <iostream>\nint main(){std::cout<<"ok\\n";return 0;}\n' > "$TMPD/cc.cc"
if command -v c++ >/dev/null 2>&1; then CXXBIN=c++; elif command -v g++ >/dev/null 2>&1; then CXXBIN=g++; else CXXBIN=clang++; fi
"$CXXBIN" -O2 "$TMPD/cc.cc" -o "$TMPD/ccx" || fail "C++ compile failed"
OUT="$("$TMPD/ccx")" || fail "C++ run failed"
[ "$OUT" = "ok" ] || fail "C++ run wrong output: $OUT"
info "C++ probe ok: $("$CXXBIN" --version | head -n1)"
printf 'int main(void){return 0;}\n' | clang -x c - -o "$TMPD/clang-c" || fail "clang C compile failed"
"$TMPD/clang-c" || fail "clang-built binary run failed"
clang --version | head -n1 | grep -q "23" || fail "clang version is not 23.x: $(clang --version | head -n1)"
clang --print-targets 2>/dev/null | grep -qi "X86" || fail "clang X86 target missing"
if [ -f /usr/lib/libLLVM-23.so ] || [ -f /usr/lib/llvm23/lib/libLLVM-23.so ]; then
  info "LLVM shared lib present"
else
  fail "libLLVM-23.so not found in /usr/lib or /usr/lib/llvm23/lib"
fi
python3 - "$PINS" "$ROOT" <<'PY' || exit 1
import json, hashlib, sys, os
p, root = sys.argv[1], sys.argv[2]
d = json.load(open(p))
for k in ("stagex_commit","image","sources","patches","containerfile","package_toml"):
    assert k in d, k
assert d["reference_endpoint"] == "1.96.0", d.get("reference_endpoint")
assert d["image"]["digest"].startswith("sha256:"), "image digest"
for sec in ("containerfile","package_toml"):
    rel = d[sec]["local_copy"]
    full = os.path.join(root, rel)
    h = hashlib.sha256(open(full,"rb").read()).hexdigest()
    assert h == d[sec]["sha256"], "%s hash mismatch %s != %s" % (sec, h, d[sec]["sha256"])
for patch in d["patches"]:
    pf = os.path.join(root, patch["file"])
    h2 = hashlib.sha256(open(pf,"rb").read()).hexdigest()
    assert h2 == patch["sha256"], "patch %s mismatch" % patch["name"]
print("doctor: pin record ok: commit %s rust %s digest %s" % (d["stagex_commit"][:12], d["reference_endpoint"], d["image"]["digest"][:19]+"..."))
PY
info "disk: $(df -h "$ROOT" | tail -n1)"
AVAIL_KB="$(df -P "$ROOT" | tail -n1 | awk '{print $4}')"
[ "$AVAIL_KB" -gt 20971520 ] || fail "disk available <20GB"
info "cpu/mem: nproc=$(nproc) $(free -g | head -n2 | tr '\n' ' ')"
if [ -r /sys/fs/cgroup/memory.max ]; then info "cgroup memory.max=$(cat /sys/fs/cgroup/memory.max)"; fi
if [ -r /sys/fs/cgroup/cpu.max ]; then info "cgroup cpu.max=$(cat /sys/fs/cgroup/cpu.max)"; fi
info "cgroup: $(cat /proc/self/cgroup 2>/dev/null | head -n3 || echo n/a)"
docker info >/dev/null 2>&1 || fail "docker info failed"
info "docker ok: $(docker --version)"
END="$(date +%s)"
ELAPSED=$((END-START))
info "elapsed ${ELAPSED}s"
[ "$ELAPSED" -lt 120 ] || fail "doctor took >=120s"
echo "doctor PASS in ${ELAPSED}s"

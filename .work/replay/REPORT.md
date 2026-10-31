# S10 partial-replay report (scope S2-S4, 2026-10-31)
## Outcome
REPLAY_OK. Fresh namespace `.work/replay/` rebuilt mrustc+minicargo, the 1.90
seed (rustc+cargo+sysroot), and 1.91.1 (rustc+cargo+sysroot) with zero imported
compiler objects and zero foreign cache entries.
## Scope statement
Replayed: S2 (C++ tools), S3 (seed+normalize), S4 (first handoff). NOT replayed:
S5 ladder rungs, S6 extension, S7 fixtures/external (reused as-is), S9 leaf
rebuilds (mechanism proven, full closure parked). Rationale: S2-S4 is the
lineage core (independent seed -> first native handoff); later rungs repeat the
proven x.py pattern with newer predecessors.
## Inputs classified
Built (recompiled here): mrustc 0.12.0, minicargo, seed rustc/cargo/sysroot,
1.91.1 rustc/cargo/sysroot, TLS shim .so (from own C source), FileCheck use.
Shared sources (byte-verified, not compiled artifacts): mrustc tarball
(c1ba35…), rustc-1.90.0 (799a9f9c…), rustc-1.91.1 (38dce205…), pins patches,
apk archives (llvm21 triple, compiler-rt, libunwind, test-utils), vendor trees.
Imported/borrowed (declared, outside claim): host cc/gcc/clang/musl, apk LLVM
binaries used as build tools, host libz/openssl/curl for cargo, mold linker,
python3/make/ninja/cmake.
Excluded: kache (neutralized, see below), ccache (CCACHE_DISABLE=1, no cache
dir created), ~/.cargo registry/index (isolated CARGO_HOME; bootstrap deps
fetched fresh with network, logged).
## Neutralization proof
RUSTC_WRAPPER=passthrough script honored by seed cargo: 1436 rustc invocations
logged in logs/passthrough.log, 0 mentioning kache. kache binary unreachable
(PATH scrubbed to /usr/bin:/bin + replay-local dirs). HOST_CC/HOST_CXX/CC/CXX
pinned to system tools (defeats config-file injection PROVEN mid-replay: psm
build script demanded `kache cc`). mold via replay-local symlink (declared tool).
## Match / difference
Match: replay 1.91.1 `rustc -vV` identical (1.91.1 ed61e7d7e, musl, LLVM 21.1.8);
smoke suite 5/5 on replay prefix (proc-macro/build.rs/FFI/threads/unwind);
cargo versions match; no toolchain downloads in replay logs (offline after fetch).
Differ (explained, not normalized): installed binaries differ byte-wise —
absolute build paths ($REPO/.work/replay vs .work/...) embedded in rpaths,
debug paths, and archive metadata; build timestamps differ. Functional equality
holds (versions, smoke); byte equality is not claimed and was not required.
## Lineage note
Dev builds used ambient kache (shared cache) for C/C++ and RUSTC_WRAPPER call
paths — a foreign-cache caveat now closed by this replay, which used none.
